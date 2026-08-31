import { describe, expect, it, vi } from "vitest";
import { shareOrCopy } from "../src/share";

const data: ShareData = {
  title: "London LSOA",
  url: "https://example.test/london/#group=income&layer=income-bhc&section=E01000001",
};

describe("share fallback", () => {
  it("uses native sharing when it succeeds", async () => {
    const share = vi.fn().mockResolvedValue(undefined);
    const copy = vi.fn().mockResolvedValue(undefined);
    await expect(shareOrCopy(data, { share, copy })).resolves.toBe("shared");
    expect(share).toHaveBeenCalledWith(data);
    expect(copy).not.toHaveBeenCalled();
  });

  it("copies the exact URL when native sharing is unavailable", async () => {
    const copy = vi.fn().mockResolvedValue(undefined);
    await expect(shareOrCopy(data, { copy })).resolves.toBe("copied");
    expect(copy).toHaveBeenCalledWith(data.url);
  });

  it("falls back to copying after a native share failure", async () => {
    const share = vi.fn().mockRejectedValue(new Error("unavailable"));
    const copy = vi.fn().mockResolvedValue(undefined);
    await expect(shareOrCopy(data, { share, copy })).resolves.toBe("copied");
    expect(copy).toHaveBeenCalledWith(data.url);
  });

  it("does not copy when the user cancels native sharing", async () => {
    const share = vi.fn().mockRejectedValue({ name: "AbortError" });
    const copy = vi.fn().mockResolvedValue(undefined);
    await expect(shareOrCopy(data, { share, copy })).resolves.toBe("aborted");
    expect(copy).not.toHaveBeenCalled();
  });
});
