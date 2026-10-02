export type SseMessage = {
  id: string | null;
  event: string | null;
  data: string;
};

function parseBlock(block: string): SseMessage | null {
  const normalized = block.replace(/\r/g, "");
  const data: string[] = [];
  let id: string | null = null;
  let event: string | null = null;

  for (const line of normalized.split("\n")) {
    if (!line || line.startsWith(":")) continue;
    const separator = line.indexOf(":");
    const field = separator >= 0 ? line.slice(0, separator) : line;
    let value = separator >= 0 ? line.slice(separator + 1) : "";
    if (value.startsWith(" ")) value = value.slice(1);

    if (field === "id") id = value;
    else if (field === "event") event = value;
    else if (field === "data") data.push(value);
  }

  if (data.length === 0) return null;
  return { id, event, data: data.join("\n") };
}

export async function* parseSseStream(
  response: Response,
  signal?: AbortSignal,
): AsyncGenerator<SseMessage> {
  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("text/event-stream")) {
    throw new Error("Expected text/event-stream response.");
  }
  if (!response.body) {
    throw new Error("SSE response body is unavailable.");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    for (;;) {
      if (signal?.aborted) return;
      const { value, done } = await reader.read();
      buffer += decoder.decode(value, { stream: !done });

      let match = /\r?\n\r?\n/.exec(buffer);
      while (match) {
        const boundary = match.index;
        const block = buffer.slice(0, boundary);
        buffer = buffer.slice(boundary + match[0].length);
        const parsed = parseBlock(block);
        if (parsed) yield parsed;
        match = /\r?\n\r?\n/.exec(buffer);
      }

      if (done) {
        const parsed = parseBlock(buffer);
        if (parsed) yield parsed;
        return;
      }
    }
  } finally {
    try {
      await reader.cancel();
    } catch {
      // The stream may already be closed by the server.
    }
  }
}
