import type { Source } from "@/api/types";

export type ParsedTikTokSource = {
  source: Source;
  handle: string;
  username: string;
};

export function parseTikTokSource(input: string): ParsedTikTokSource | null {
  const value = input.trim();
  if (!value) return null;

  const urlMatch = value.match(
    /^(?:https?:\/\/)?(?:www\.)?tiktok\.com\/@([A-Za-z0-9._]{2,24})(?:[/?#].*)?$/i,
  );
  const rawUsername = urlMatch?.[1] ?? value.replace(/^@/, "");
  if (!/^[A-Za-z0-9._]{2,24}$/.test(rawUsername)) return null;

  const username = rawUsername.toLowerCase();
  return {
    source: { type: "username", value: username },
    handle: `@${username}`,
    username,
  };
}

export function displayNameFromTikTokUsername(username: string): string {
  return username
    .replace(/^@/, "")
    .replace(/[._]+/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}
