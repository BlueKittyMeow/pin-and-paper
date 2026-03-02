export type ErrorCode =
  | "NOT_FOUND"
  | "VALIDATION_ERROR"
  | "DUPLICATE_NAME"
  | "UNAUTHORIZED"
  | "INTERNAL_ERROR"
  | "DEPTH_EXCEEDED";

/** Return a structured MCP tool error. */
export function toolError(code: ErrorCode, message: string) {
  return {
    content: [
      {
        type: "text" as const,
        text: JSON.stringify({ error: { code, message } }),
      },
    ],
    isError: true,
  };
}

/** Return a successful MCP tool result. */
export function toolSuccess(data: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data) }],
  };
}
