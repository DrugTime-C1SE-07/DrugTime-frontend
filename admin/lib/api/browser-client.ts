const messages: Record<number, string> = {
  401: "Phiên không hợp lệ hoặc đã hết hạn. Hãy đăng xuất và đăng nhập lại.",
  403: "Bạn không có quyền thực hiện thao tác này.",
  404: "Bản ghi không còn tồn tại. Hãy tải lại danh sách.",
  409: "Dữ liệu đã thay đổi hoặc bị trùng. Hãy tải lại và đối chiếu trước khi lưu.",
  422: "Dữ liệu không hợp lệ. Kiểm tra các trường và ràng buộc trước khi lưu.",
  429: "Bạn thao tác quá nhanh. Hãy thử lại sau.",
};

export class BrowserApiError extends Error {
  constructor(readonly status: number, method = "GET") {
    super(method === "POST" && (status === 0 || status >= 500)
      ? "Chưa xác định được kết quả lưu. Hãy tải lại danh sách để kiểm tra trước khi gửi lại."
      : messages[status] ?? "Không kết nối được máy chủ. Hãy thử tải lại dữ liệu.");
  }
}

export async function browserRequest<T>(path: string, options: RequestInit = {}): Promise<T> {
  const method = options.method ?? "GET";
  let response: Response;
  try {
    response = await fetch(path, { ...options, cache: "no-store" });
  } catch (error) {
    if (options.signal?.aborted) throw error;
    throw new BrowserApiError(0, method);
  }
  options.signal?.throwIfAborted();
  if (!response.ok) throw new BrowserApiError(response.status, method);
  if (response.status === 204) return undefined as T;
  try {
    const data: T = await response.json();
    options.signal?.throwIfAborted();
    return data;
  } catch (error) {
    if (options.signal?.aborted) throw error;
    throw new BrowserApiError(502, method);
  }
}

export function jsonOptions(method: string, body: unknown): RequestInit {
  return { method, headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) };
}
