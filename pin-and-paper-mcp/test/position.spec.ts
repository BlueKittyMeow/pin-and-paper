import { describe, it, expect } from 'vitest';
import {
	minSiblingPosition,
	topInsertPosition,
	planBatchPositions,
} from '../../supabase/functions/mcp-server/helpers/position.ts';

// New-task-top-insert semantics (docs/specs/new-task-top-insert.md): the list
// is ordered by position ascending, new tasks insert at MIN(position) - 1
// over non-deleted siblings, batches take MIN - n .. MIN - 1 in input order.

interface Row {
	position: number;
	parent_id: string | null;
	user_id: string;
	deleted_at: string | null;
}

const USER = 'user-1';

function row(position: number, overrides: Partial<Row> = {}): Row {
	return { position, parent_id: null, user_id: USER, deleted_at: null, ...overrides };
}

/**
 * Minimal in-memory stand-in for the supabase-js query builder, covering the
 * exact chain position.ts uses: from().select().eq().is().order().limit()
 * awaited as { data, error }.
 */
function fakeSupabase(rows: Row[], opts: { failWith?: string } = {}) {
	return {
		from(_table: string) {
			let filtered = [...rows];
			const builder = {
				select(_cols: string) {
					return builder;
				},
				eq(col: keyof Row, val: unknown) {
					filtered = filtered.filter((r) => r[col] === val);
					return builder;
				},
				is(col: keyof Row, val: null) {
					filtered = filtered.filter((r) => r[col] === val);
					return builder;
				},
				order(col: keyof Row, { ascending }: { ascending: boolean }) {
					filtered.sort((a, b) =>
						ascending ? (a[col] as number) - (b[col] as number) : (b[col] as number) - (a[col] as number)
					);
					return builder;
				},
				limit(n: number) {
					filtered = filtered.slice(0, n);
					return builder;
				},
				then(resolve: (v: unknown) => unknown, reject: (e: unknown) => unknown) {
					const result = opts.failWith
						? { data: null, error: { message: opts.failWith } }
						: { data: filtered.map((r) => ({ position: r.position })), error: null };
					return Promise.resolve(result).then(resolve, reject);
				},
			};
			return builder;
		},
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
	} as any;
}

describe('minSiblingPosition', () => {
	it('defaults to 1 when there are no siblings (COALESCE(MIN, 1))', async () => {
		expect(await minSiblingPosition(fakeSupabase([]), null, USER)).toBe(1);
	});

	it('returns the minimum among root siblings', async () => {
		const db = fakeSupabase([row(0), row(3), row(-2)]);
		expect(await minSiblingPosition(db, null, USER)).toBe(-2);
	});

	it('ignores soft-deleted siblings', async () => {
		const db = fakeSupabase([row(-5, { deleted_at: '2026-08-01T00:00:00Z' }), row(0), row(1)]);
		expect(await minSiblingPosition(db, null, USER)).toBe(0);
	});

	it('scopes root queries to parent_id IS NULL', async () => {
		const db = fakeSupabase([row(-10, { parent_id: 'p1' }), row(2)]);
		expect(await minSiblingPosition(db, null, USER)).toBe(2);
	});

	it('scopes child queries to the given parent', async () => {
		const db = fakeSupabase([row(-4), row(3, { parent_id: 'p1' }), row(7, { parent_id: 'p2' })]);
		expect(await minSiblingPosition(db, 'p1', USER)).toBe(3);
	});

	it('scopes to the given user', async () => {
		const db = fakeSupabase([row(-9, { user_id: 'someone-else' }), row(1)]);
		expect(await minSiblingPosition(db, null, USER)).toBe(1);
	});

	it('throws on query error', async () => {
		const db = fakeSupabase([], { failWith: 'boom' });
		await expect(minSiblingPosition(db, null, USER)).rejects.toThrow('boom');
	});
});

describe('topInsertPosition', () => {
	it('is 0 for the very first task (matches the app default)', async () => {
		expect(await topInsertPosition(fakeSupabase([]), null, USER)).toBe(0);
	});

	it('goes below an already-negative minimum', async () => {
		const db = fakeSupabase([row(-3), row(0), row(2)]);
		expect(await topInsertPosition(db, null, USER)).toBe(-4);
	});

	it('keeps descending across sequential creates', async () => {
		const rows: Row[] = [];
		const seen: number[] = [];
		for (let i = 0; i < 3; i++) {
			const pos = await topInsertPosition(fakeSupabase(rows), null, USER);
			seen.push(pos);
			rows.push(row(pos));
		}
		expect(seen).toEqual([0, -1, -2]);
	});
});

describe('planBatchPositions', () => {
	it('assigns MIN - n .. MIN - 1 in input order for one parent', async () => {
		const db = fakeSupabase([row(-2), row(0)]);
		const positions = await planBatchPositions(db, [null, null, null], USER);
		expect(positions).toEqual([-5, -4, -3]);
		// Whole batch sits above existing tasks, first input topmost.
		expect(Math.max(...positions)).toBeLessThan(-2);
	});

	it('starts from the empty-list default for a fresh list', async () => {
		expect(await planBatchPositions(fakeSupabase([]), [null, null], USER)).toEqual([-1, 0]);
	});

	it('plans each distinct parent independently, preserving input order', async () => {
		const db = fakeSupabase([row(0), row(5, { parent_id: 'p1' })]);
		const positions = await planBatchPositions(db, [null, 'p1', null, 'p1'], USER);
		// Roots: min 0, two new -> -2, -1. Children of p1: min 5, two new -> 3, 4.
		expect(positions).toEqual([-2, 3, -1, 4]);
	});

	it('defaults for a parent with no rows yet (parent created in the same batch)', async () => {
		const db = fakeSupabase([row(0)]);
		expect(await planBatchPositions(db, ['not-yet-created'], USER)).toEqual([0]);
	});

	it('handles an empty batch', async () => {
		expect(await planBatchPositions(fakeSupabase([]), [], USER)).toEqual([]);
	});
});
