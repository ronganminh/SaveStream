import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

export type Language = "en" | "vi";
export type ThemePreference = "light" | "dark" | "system";

const vi: Record<string, string> = {
  Features: "Tính năng",
  "How it works": "Cách hoạt động",
  Examples: "Bản ghi mẫu",
  Pricing: "Bảng giá",
  FAQ: "Hỏi đáp",
  "Sign in": "Đăng nhập",
  "Sign up": "Đăng ký",
  "Create account": "Tạo tài khoản",
  "Sign out": "Đăng xuất",
  "Go home": "Về trang chủ",
  Overview: "Tổng quan",
  Channels: "Kênh",
  Recordings: "Bản ghi",
  "Usage & Billing": "Sử dụng & Thanh toán",
  Usage: "Mức sử dụng",
  Billing: "Thanh toán",
  Workspace: "Không gian làm việc",
  Notifications: "Thông báo",
  Settings: "Cài đặt",
  Help: "Trợ giúp",
  Admin: "Quản trị",
  System: "Hệ thống",
  Workers: "Tiến trình",
  Jobs: "Tác vụ",
  Errors: "Lỗi",
  "Search channels or recordings": "Tìm kênh hoặc bản ghi",
  "Search channels or recordings…": "Tìm kênh hoặc bản ghi…",
  Search: "Tìm kiếm",
  Account: "Tài khoản",
  "View all notifications": "Xem tất cả thông báo",
  "Mark all read": "Đánh dấu đã đọc",
  Light: "Sáng",
  Dark: "Tối",
  "System theme": "Hệ thống",
  Theme: "Giao diện",
  Language: "Ngôn ngữ",
  English: "English",
  "Tiếng Việt": "Tiếng Việt",
  "Automatic cloud recording": "Tự động ghi hình trên đám mây",
  "Automatic TikTok livestream recording in the cloud.":
    "Tự động ghi livestream TikTok trên đám mây.",
  "Add a channel once. We monitor it 24/7 and automatically record every livestream — even when your computer is offline.":
    "Chỉ cần thêm kênh một lần. Chúng tôi theo dõi 24/7 và tự động ghi mọi livestream — kể cả khi máy tính của bạn đang tắt.",
  "Start for free": "Bắt đầu miễn phí",
  "Start recording free": "Ghi hình miễn phí",
  "See how it works": "Xem cách hoạt động",
  "No credit card required.": "Không cần thẻ thanh toán.",
  "Set it once. We handle the rest.": "Thiết lập một lần. Chúng tôi lo phần còn lại.",
  "Add a channel": "Thêm kênh",
  "We monitor it": "Chúng tôi theo dõi",
  "Recording starts": "Bắt đầu ghi hình",
  "Watch later": "Xem lại sau",
  "Cloud by design": "Được xây dựng cho đám mây",
  "Close your laptop. Recording continues.": "Đóng máy tính. Việc ghi hình vẫn tiếp tục.",
  "Monitoring and recording run on our servers, not in your browser.":
    "Theo dõi và ghi hình chạy trên máy chủ của chúng tôi, không phải trong trình duyệt của bạn.",
  "Automatic live detection": "Tự động phát hiện livestream",
  "Cloud recording": "Ghi hình đám mây",
  "Multiple monitored channels": "Theo dõi nhiều kênh",
  "Recording library": "Thư viện bản ghi",
  "Browser playback": "Phát trong trình duyệt",
  "Fast downloads": "Tải xuống nhanh",
  "Usage tracking": "Theo dõi mức sử dụng",
  "Retention cleanup": "Tự động dọn theo thời hạn",
  "Completed recordings": "Bản ghi đã hoàn tất",
  "Recording Examples": "Bản ghi mẫu",
  "See what a completed cloud recording looks like. These samples use prototype data.":
    "Xem một bản ghi đám mây hoàn chỉnh trông như thế nào. Các mẫu này sử dụng dữ liệu mô phỏng.",
  "Start recording your own livestreams": "Bắt đầu ghi livestream của bạn",
  "Demo preview": "Bản xem thử",
  SAMPLE: "BẢN MẪU",
  "Simple plans, clear limits.": "Gói đơn giản, giới hạn rõ ràng.",
  "Frequently asked questions": "Câu hỏi thường gặp",
  Product: "Sản phẩm",
  Legal: "Pháp lý",
  Status: "Trạng thái",
  Privacy: "Quyền riêng tư",
  Terms: "Điều khoản",
  "Acceptable use": "Sử dụng chấp nhận được",
  "Welcome back": "Chào mừng bạn trở lại",
  "Sign in to manage your recordings.": "Đăng nhập để quản lý các bản ghi.",
  "Create your account": "Tạo tài khoản",
  "Start monitoring your first TikTok channel.": "Bắt đầu theo dõi kênh TikTok đầu tiên.",
  "Reset your password": "Đặt lại mật khẩu",
  "Choose a new password": "Chọn mật khẩu mới",
  Email: "Email",
  Password: "Mật khẩu",
  "Full name": "Họ và tên",
  "Forgot password?": "Quên mật khẩu?",
  "Continue with Google": "Tiếp tục với Google",
  "or continue with email": "hoặc tiếp tục bằng email",
  "Back to sign in": "Quay lại đăng nhập",
  "Check your email": "Kiểm tra email",
  "Password updated": "Đã cập nhật mật khẩu",
  "Let’s record your first livestream.": "Hãy ghi livestream đầu tiên của bạn.",
  "Add my first channel": "Thêm kênh đầu tiên",
  "Coming soon": "Sắp ra mắt",
  Available: "Khả dụng",
  "Resolving creator…": "Đang tìm nhà sáng tạo…",
  "Add & start monitoring": "Thêm & bắt đầu theo dõi",
  "Monitoring on": "Đang theo dõi",
  "Go to dashboard": "Đi tới bảng điều khiển",
  "Add channel": "Thêm kênh",
  "Active channels": "Kênh đang hoạt động",
  "Stored recordings": "Bản ghi đã lưu",
  "Recording hours": "Giờ ghi hình",
  "Download usage": "Lưu lượng tải xuống",
  "Channel monitoring": "Theo dõi kênh",
  "Recent recordings": "Bản ghi gần đây",
  "View all": "Xem tất cả",
  "View library": "Xem thư viện",
  Creator: "Nhà sáng tạo",
  Platform: "Nền tảng",
  Monitoring: "Theo dõi",
  "Last checked": "Kiểm tra gần nhất",
  All: "Tất cả",
  Recording: "Đang ghi",
  Processing: "Đang xử lý",
  Ready: "Sẵn sàng",
  Waiting: "Đang chờ",
  Offline: "Ngoại tuyến",
  Paused: "Tạm dừng",
  Error: "Lỗi",
  New: "Mới",
  "No channels found": "Không tìm thấy kênh",
  View: "Xem",
  "View channel": "Xem kênh",
  "Pause monitoring": "Tạm dừng theo dõi",
  "Resume monitoring": "Tiếp tục theo dõi",
  "Remove channel": "Xóa kênh",
  Cancel: "Hủy",
  "Try again": "Thử lại",
  "Upgrade plan": "Nâng cấp gói",
  "Watch and download your completed livestream recordings.":
    "Xem và tải xuống các bản ghi livestream đã hoàn tất.",
  "Search recordings": "Tìm bản ghi",
  "All streamers": "Tất cả kênh",
  "All statuses": "Tất cả trạng thái",
  "All time": "Mọi thời điểm",
  "Newest first": "Mới nhất trước",
  "Oldest first": "Cũ nhất trước",
  "List view": "Dạng danh sách",
  "Grid view": "Dạng lưới",
  Duration: "Thời lượng",
  Size: "Dung lượng",
  Expires: "Hết hạn",
  Download: "Tải xuống",
  Delete: "Xóa",
  "Download video": "Tải video",
  "Delete recording": "Xóa bản ghi",
  "No recordings yet": "Chưa có bản ghi",
  "Finalizing your recording": "Đang hoàn thiện bản ghi",
  "Current plan": "Gói hiện tại",
  "Current subscription": "Gói đăng ký hiện tại",
  "Manage plan": "Quản lý gói",
  "Manage subscription": "Quản lý đăng ký",
  "Upgrade to Pro": "Nâng cấp lên Pro",
  Monthly: "Hàng tháng",
  Yearly: "Hàng năm",
  "Save 20%": "Tiết kiệm 20%",
  "Payment method": "Phương thức thanh toán",
  "Billing history": "Lịch sử thanh toán",
  "No invoices yet.": "Chưa có hóa đơn.",
  Active: "Đang hoạt động",
  "Payment failed": "Thanh toán thất bại",
  "Past due": "Quá hạn",
  "Manage your account, notifications, and security.": "Quản lý tài khoản, thông báo và bảo mật.",
  Security: "Bảo mật",
  Profile: "Hồ sơ",
  Name: "Tên",
  "Save changes": "Lưu thay đổi",
  "Export your data": "Xuất dữ liệu",
  "Request data export": "Yêu cầu xuất dữ liệu",
  "Delete account": "Xóa tài khoản",
  "Email notifications": "Thông báo qua email",
  "Save preferences": "Lưu tùy chọn",
  Saved: "Đã lưu",
  "Change password": "Đổi mật khẩu",
  "Current password": "Mật khẩu hiện tại",
  "New password": "Mật khẩu mới",
  "Confirm new password": "Xác nhận mật khẩu mới",
  "Update password": "Cập nhật mật khẩu",
  "Active sessions": "Phiên đang hoạt động",
  "Sign-in methods": "Phương thức đăng nhập",
  Connected: "Đã kết nối",
  "Not connected": "Chưa kết nối",
  Connect: "Kết nối",
  "Recording activity, failures, and quota alerts.": "Hoạt động ghi hình, lỗi và cảnh báo hạn mức.",
  Unread: "Chưa đọc",
  "Mark all as read": "Đánh dấu tất cả đã đọc",
  "No unread notifications": "Không có thông báo chưa đọc",
  "No notifications yet": "Chưa có thông báo",
  "You’re all caught up.": "Bạn đã xem hết thông báo.",
  "System status": "Trạng thái hệ thống",
  "All systems operational": "Tất cả hệ thống hoạt động bình thường",
  "Some systems are degraded": "Một số hệ thống đang suy giảm",
  "Recent incidents": "Sự cố gần đây",
  Operational: "Hoạt động",
  Degraded: "Suy giảm",
  Today: "Hôm nay",
  "Terms of Service": "Điều khoản dịch vụ",
  "Privacy Policy": "Chính sách quyền riêng tư",
  "Acceptable Use Policy": "Chính sách sử dụng chấp nhận được",
  "Last updated September 27, 2026": "Cập nhật lần cuối ngày 27 tháng 9, 2026",
  "The service": "Dịch vụ",
  "Your responsibility for content": "Trách nhiệm của bạn với nội dung",
  "Retention and deletion": "Lưu giữ và xóa",
  Availability: "Khả dụng",
  Termination: "Chấm dứt",
  Contact: "Liên hệ",
  Allowed: "Được phép",
  "Not allowed": "Không được phép",
  Enforcement: "Thực thi",
  Reporting: "Báo cáo",
  "Getting started": "Bắt đầu",
  "How cloud monitoring works": "Cách theo dõi đám mây hoạt động",
  "Recording lifecycle": "Vòng đời bản ghi",
  Quotas: "Hạn mức",
  Retention: "Thời hạn lưu",
  "Failed recording troubleshooting": "Khắc phục lỗi ghi hình",
  "Authorized recording policy": "Chính sách ghi hình được phép",
  "Contact support": "Liên hệ hỗ trợ",
  "Still need help?": "Vẫn cần trợ giúp?",
  Subject: "Chủ đề",
  Message: "Nội dung",
  "Send message": "Gửi tin nhắn",
  Online: "Trực tuyến",
  Idle: "Rảnh",
  "Service health": "Tình trạng dịch vụ",
  "Recording jobs": "Tác vụ ghi hình",
  "Job ID": "Mã tác vụ",
  Worker: "Tiến trình",
  Started: "Bắt đầu",
  Retries: "Số lần thử",
  Heartbeat: "Nhịp hoạt động",
  Failed: "Thất bại",
  Stuck: "Bị kẹt",
  "Errors & events": "Lỗi & sự kiện",
  Severity: "Mức độ",
  Service: "Dịch vụ",
  State: "Trạng thái",
  Open: "Đang mở",
  Resolved: "Đã xử lý",
  Retrying: "Đang thử lại",
  Timeline: "Dòng thời gian",
  "Job context": "Ngữ cảnh tác vụ",
  "Page not found": "Không tìm thấy trang",
  "This page didn't load": "Trang này không tải được",
  Loading: "Đang tải",
  "No results found": "Không tìm thấy kết quả",
  "Clear filters": "Xóa bộ lọc",
  "Clear search": "Xóa tìm kiếm",
  "More actions": "Thao tác khác",
  "Do I need to keep my computer on?": "Tôi có cần bật máy tính không?",
  "Which channels can I add?": "Tôi có thể thêm những kênh nào?",
  "How long are recordings kept?": "Bản ghi được lưu trong bao lâu?",
  "What happens if I reach my quota?": "Điều gì xảy ra khi tôi đạt hạn mức?",
  "Plans that scale with your livestreams.": "Các gói linh hoạt theo livestream của bạn.",
  "Start free. Upgrade when you need more recording time.":
    "Bắt đầu miễn phí. Nâng cấp khi bạn cần thêm thời gian ghi hình.",
  "Start with Pro": "Bắt đầu với Pro",
  "Yearly billing saves 20%. Cancel anytime from Billing.":
    "Thanh toán hàng năm tiết kiệm 20%. Có thể hủy bất cứ lúc nào trong mục Thanh toán.",
  "Channel details": "Chi tiết kênh",
  "Channel not found": "Không tìm thấy kênh",
  "Recording details": "Chi tiết bản ghi",
  "Active recording": "Bản ghi đang chạy",
  "Failed recording": "Bản ghi thất bại",
  "Processing recording": "Đang xử lý bản ghi",
  "Recording not found": "Không tìm thấy bản ghi",
  "Current period": "Kỳ hiện tại",
  "Concurrent limit": "Giới hạn đồng thời",
  "Download bandwidth": "Băng thông tải xuống",
  "Plan limits": "Giới hạn gói",
  "Daily recording hours": "Giờ ghi hình hằng ngày",
  "Usage by recording": "Mức sử dụng theo bản ghi",
  "Monitored channels": "Kênh đang theo dõi",
  "Manage your plan, payment method, and invoices.":
    "Quản lý gói, phương thức thanh toán và hóa đơn.",
  Plans: "Các gói",
  Free: "Miễn phí",
  "Choose plan": "Chọn gói",
  "Downgrade to Free": "Hạ xuống gói Free",
  "Cancel subscription": "Hủy đăng ký",
  "Update payment method": "Cập nhật thanh toán",
  "Pay now": "Thanh toán ngay",
  "Resume subscription": "Tiếp tục đăng ký",
  "Verification email sent": "Đã gửi email xác minh",
  "Resend verification email": "Gửi lại email xác minh",
  "Change email": "Đổi email",
  "Email verified": "Email đã được xác minh",
  "Continue to setup": "Tiếp tục thiết lập",
  "Request a new link": "Yêu cầu liên kết mới",
  "This link has expired": "Liên kết đã hết hạn",
  "This link isn’t valid": "Liên kết không hợp lệ",
  "We couldn’t verify your email": "Không thể xác minh email của bạn",
  "Recording started": "Đã bắt đầu ghi",
  "Recording ready": "Bản ghi đã sẵn sàng",
  "Recording failed": "Ghi hình thất bại",
  "Quota warning": "Cảnh báo hạn mức",
  "Recording completed": "Ghi hình hoàn tất",
  "Retention / expiration warning": "Cảnh báo lưu giữ / hết hạn",
  "Draft — for legal review before launch": "Bản nháp — cần pháp lý duyệt trước khi ra mắt",
  "Authorized recording only": "Chỉ ghi hình khi được phép",
  "Information we collect": "Thông tin chúng tôi thu thập",
  "How we use it": "Cách chúng tôi sử dụng",
  "Your choices": "Lựa chọn của bạn",
  "Service providers": "Nhà cung cấp dịch vụ",
  "Your responsibility": "Trách nhiệm của bạn",
  "Plans, quotas, and billing": "Gói, hạn mức và thanh toán",
  "Live operational health across recording infrastructure.":
    "Tình trạng vận hành trực tiếp của hạ tầng ghi hình.",
  "Active workers": "Tiến trình hoạt động",
  "Active recordings": "Bản ghi đang chạy",
  "Queue depth": "Độ dài hàng đợi",
  "Failed jobs · 24h": "Tác vụ lỗi · 24 giờ",
  "Storage used": "Dung lượng đã dùng",
  "API errors · 1h": "Lỗi API · 1 giờ",
  "Updated just now": "Vừa cập nhật",
  "Recorder and processor worker health.": "Tình trạng các tiến trình ghi và xử lý.",
  "Current job": "Tác vụ hiện tại",
  Memory: "Bộ nhớ",
  Version: "Phiên bản",
  "Drain worker": "Ngừng nhận tác vụ",
  "View details & logs": "Xem chi tiết & nhật ký",
  Inspect: "Kiểm tra",
  "Retry job": "Thử lại tác vụ",
  "Mark as failed": "Đánh dấu thất bại",
  "System events across monitoring, workers, processing, and storage.":
    "Sự kiện hệ thống trong theo dõi, tiến trình, xử lý và lưu trữ.",
  "All severities": "Mọi mức độ",
  "All states": "Mọi trạng thái",
  "No events match": "Không có sự kiện phù hợp",
  "Details / stack (placeholder)": "Chi tiết / ngăn xếp (mẫu)",
};

type Preferences = {
  language: Language;
  setLanguage: (language: Language) => void;
  theme: ThemePreference;
  setTheme: (theme: ThemePreference) => void;
  t: (text: string) => string;
};
const Context = createContext<Preferences | null>(null);
const originalText = new WeakMap<Node, string>();

function translate(text: string, language: Language) {
  if (language === "en") return text;
  const exact = vi[text];
  if (exact) return exact;
  return text
    .replace(/\brecordings\b/gi, (match) => (match[0] === "R" ? "Bản ghi" : "bản ghi"))
    .replace(/\bchannels\b/gi, (match) => (match[0] === "C" ? "Kênh" : "kênh"))
    .replace(/\bminutes\b/gi, "phút")
    .replace(/\bhours\b/gi, "giờ")
    .replace(/\bdays\b/gi, "ngày")
    .replace(/\bago\b/gi, "trước");
}

function applyTheme(theme: ThemePreference) {
  const dark =
    theme === "dark" ||
    (theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.classList.toggle("dark", dark);
  document.documentElement.dataset["theme"] = theme;
  document.documentElement.style.colorScheme = dark ? "dark" : "light";
}

export function PreferencesProvider({ children }: { children: ReactNode }) {
  const [language, setLanguageState] = useState<Language>("en");
  const [theme, setThemeState] = useState<ThemePreference>("system");
  useEffect(() => {
    const savedLanguage = localStorage.getItem("savestream-language");
    const nextLanguage: Language =
      savedLanguage === "vi" || savedLanguage === "en"
        ? savedLanguage
        : navigator.language.toLowerCase().startsWith("vi")
          ? "vi"
          : "en";
    const savedTheme = localStorage.getItem("savestream-theme");
    const nextTheme: ThemePreference =
      savedTheme === "light" || savedTheme === "dark" || savedTheme === "system"
        ? savedTheme
        : "system";
    setLanguageState(nextLanguage);
    setThemeState(nextTheme);
    applyTheme(nextTheme);
  }, []);
  useEffect(() => {
    applyTheme(theme);
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const update = () => theme === "system" && applyTheme("system");
    media.addEventListener("change", update);
    return () => media.removeEventListener("change", update);
  }, [theme]);
  useEffect(() => {
    document.documentElement.lang = language;
    const localize = (root: Node) => {
      const nodes: Node[] = [];
      if (root.nodeType === Node.TEXT_NODE) nodes.push(root);
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) nodes.push(walker.currentNode);
      for (const node of nodes) {
        const parent = node.parentElement;
        if (!parent || ["SCRIPT", "STYLE", "CODE", "PRE"].includes(parent.tagName)) continue;
        const original = originalText.get(node) ?? node.textContent ?? "";
        originalText.set(node, original);
        const trimmed = original.trim();
        if (!trimmed) continue;
        const translated = translate(trimmed, language);
        node.textContent = original.replace(trimmed, translated);
      }
      const elements: HTMLElement[] =
        root instanceof HTMLElement
          ? [root, ...root.querySelectorAll<HTMLElement>("[placeholder],[aria-label],[title]")]
          : [];
      for (const element of elements)
        for (const attr of ["placeholder", "aria-label", "title"]) {
          const value = element.getAttribute(attr);
          if (!value) continue;
          const key = `i18n${attr.replace(/(^|-)(\w)/g, (_, _dash, char) => char.toUpperCase())}`;
          const original = element.dataset[key] ?? value;
          element.dataset[key] = original;
          element.setAttribute(attr, translate(original, language));
        }
    };
    localize(document.body);
    const observer = new MutationObserver((records) => {
      observer.disconnect();
      records.forEach((record) => record.addedNodes.forEach(localize));
      localize(document.body);
      observer.observe(document.body, { childList: true, subtree: true });
    });
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [language]);
  const value = useMemo<Preferences>(
    () => ({
      language,
      setLanguage: (next) => {
        localStorage.setItem("savestream-language", next);
        setLanguageState(next);
      },
      theme,
      setTheme: (next) => {
        localStorage.setItem("savestream-theme", next);
        setThemeState(next);
      },
      t: (text) => translate(text, language),
    }),
    [language, theme],
  );
  return <Context.Provider value={value}>{children}</Context.Provider>;
}

export function usePreferences() {
  const value = useContext(Context);
  if (!value) throw new Error("usePreferences must be used inside PreferencesProvider");
  return value;
}

export const themeInitScript = `(function(){try{var t=localStorage.getItem('savestream-theme')||'system';var d=t==='dark'||(t==='system'&&matchMedia('(prefers-color-scheme: dark)').matches);document.documentElement.classList.toggle('dark',d);document.documentElement.dataset.theme=t;document.documentElement.style.colorScheme=d?'dark':'light'}catch(e){}})()`;