-- MCP Server helper functions
-- These handle operations that PostgREST cannot do:
-- recursive CTEs, positional arithmetic, and aggregate FILTER clauses.

-- 1. Shift sibling positions up by 1 to make room at position 0
CREATE OR REPLACE FUNCTION shift_sibling_positions(p_parent_id UUID, p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE tasks
  SET position = position + 1
  WHERE user_id = p_user_id
    AND deleted_at IS NULL
    AND (
      (p_parent_id IS NULL AND parent_id IS NULL)
      OR parent_id = p_parent_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION shift_sibling_positions(UUID, UUID) TO authenticated;

-- 2. Soft-delete a task and all its descendants
CREATE OR REPLACE FUNCTION soft_delete_task_tree(p_task_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  affected INTEGER;
BEGIN
  WITH RECURSIVE descendants AS (
    SELECT id FROM tasks WHERE id = p_task_id
    UNION ALL
    SELECT t.id FROM tasks t
    INNER JOIN descendants d ON t.parent_id = d.id
    WHERE t.deleted_at IS NULL
  )
  UPDATE tasks SET deleted_at = NOW()
  WHERE id IN (SELECT id FROM descendants)
    AND deleted_at IS NULL;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

GRANT EXECUTE ON FUNCTION soft_delete_task_tree(UUID) TO authenticated;

-- 3. Restore a task and descendants deleted at the same time (±1 second)
CREATE OR REPLACE FUNCTION restore_task_tree(p_task_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  task_deleted_at TIMESTAMPTZ;
  affected INTEGER;
BEGIN
  SELECT deleted_at INTO task_deleted_at
  FROM tasks WHERE id = p_task_id;

  IF task_deleted_at IS NULL THEN
    RAISE EXCEPTION 'Task is not deleted';
  END IF;

  WITH RECURSIVE descendants AS (
    SELECT id FROM tasks WHERE id = p_task_id
    UNION ALL
    SELECT t.id FROM tasks t
    INNER JOIN descendants d ON t.parent_id = d.id
    WHERE t.deleted_at BETWEEN task_deleted_at - INTERVAL '1 second'
                          AND task_deleted_at + INTERVAL '1 second'
  )
  UPDATE tasks SET deleted_at = NULL
  WHERE id IN (SELECT id FROM descendants);
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

GRANT EXECUTE ON FUNCTION restore_task_tree(UUID) TO authenticated;

-- 4. Get task summary counts in a single query
CREATE OR REPLACE FUNCTION get_task_summary()
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'active', COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false),
    'completed', COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = true),
    'overdue', COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false AND due_date < NOW()),
    'due_today', COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false AND due_date::date = CURRENT_DATE),
    'due_this_week', COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = false AND due_date BETWEEN NOW() AND NOW() + INTERVAL '7 days'),
    'in_trash', COUNT(*) FILTER (WHERE deleted_at IS NOT NULL),
    'recent_completions_7d', COUNT(*) FILTER (WHERE deleted_at IS NULL AND completed = true AND completed_at >= NOW() - INTERVAL '7 days')
  ) INTO result
  FROM tasks
  WHERE user_id = auth.uid();
  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_task_summary() TO authenticated;

-- 5. Get max depth of a task's descendants (for move validation)
CREATE OR REPLACE FUNCTION get_descendant_max_depth(p_task_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  max_depth INTEGER;
BEGIN
  WITH RECURSIVE descendants AS (
    SELECT id, 0 as depth FROM tasks WHERE id = p_task_id
    UNION ALL
    SELECT t.id, d.depth + 1 FROM tasks t
    INNER JOIN descendants d ON t.parent_id = d.id
    WHERE t.deleted_at IS NULL
  )
  SELECT MAX(depth) INTO max_depth FROM descendants;
  RETURN COALESCE(max_depth, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION get_descendant_max_depth(UUID) TO authenticated;
