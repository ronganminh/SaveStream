import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";

export type Locale = "en" | "vi";
export type ThemePreference = "system" | "light" | "dark";

const en = {
  "preferences.language": "Language",
  "preferences.theme": "Theme",
  "preferences.english": "English",
  "preferences.vietnamese": "Vietnamese",
  "theme.system": "System",
  "theme.light": "Light",
  "theme.dark": "Dark",
  "nav.features": "Features",
  "nav.how": "How it works",
  "nav.platforms": "Platforms",
  "nav.examples": "Examples",
  "nav.pricing": "Pricing",
  "nav.signIn": "Sign in",
  "nav.signUp": "Sign up",
  "nav.overview": "Overview",
  "nav.channels": "Channels",
  "nav.recordings": "Recordings",
  "nav.usage": "Usage & Billing",
  "nav.notifications": "Notifications",
  "nav.settings": "Settings",
  "nav.help": "Help",
  "nav.openMenu": "Open menu",
  "nav.closeMenu": "Close menu",
  "nav.toggleTheme": "Change theme",
  "nav.plan": "plan",
  "cta.startRecording": "Start recording free",
  "cta.seeHow": "See how it works",
  "cta.visitPartner": "Visit partner channel",
  "hero.badge": "Automatic cloud recording",
  "hero.title": "Automatic TikTok livestream recording in the cloud.",
  "hero.body": "Add a channel once. SaveStream monitors it continuously and automatically records every livestream — even when your computer is offline.",
  "hero.noCard": "No credit card required.",
  "preview.overview": "Overview",
  "preview.workspace": "Your recording workspace",
  "preview.addChannel": "Add channel",
  "preview.recordingHours": "Recording hours",
  "preview.activeChannels": "Active channels",
  "preview.stored": "Stored",
  "preview.used": "25% used",
  "preview.monitoring": "3 monitoring",
  "preview.recordings": "4 recordings",
  "preview.activeRecording": "ACTIVE RECORDING",
  "preview.written": "3.8 GB written",
  "how.eyebrow": "How it works",
  "how.title": "Set it once. We handle the rest.",
  "how.add.title": "Add a channel",
  "how.add.body": "Paste a TikTok username or profile URL.",
  "how.monitor.title": "We monitor it",
  "how.monitor.body": "Cloud workers check the channel continuously.",
  "how.record.title": "Recording starts",
  "how.record.body": "Recording begins automatically when the channel goes live.",
  "how.watch.title": "Watch later",
  "how.watch.body": "The completed video appears in your library.",
  "features.eyebrow": "Cloud by design",
  "features.title": "Close your laptop. Recording continues.",
  "features.body": "Monitoring and recording run on our servers, not in your browser.",
  "features.liveDetection": "Automatic live detection",
  "features.cloudRecording": "Cloud recording",
  "features.multiChannel": "Multiple monitored channels",
  "features.library": "Recording library",
  "features.playback": "Browser playback",
  "features.downloads": "Fast downloads",
  "features.usage": "Usage tracking",
  "features.retention": "Retention cleanup",
  "platforms.eyebrow": "Supported Platforms",
  "platforms.title": "TikTok Live first. Douyin is planned next.",
  "platforms.body": "The MVP focuses on a reliable TikTok recording workflow before expanding the same cloud automation model to Douyin.",
  "platforms.available": "Available",
  "platforms.planned": "Planned",
  "platforms.tiktok.body": "Automatic monitoring, server-side recording, processing, playback and download are the core SaveStream MVP workflow.",
  "platforms.douyin.body": "Douyin support is planned after the TikTok MVP, worker reliability and recording lifecycle are stable.",
  "examples.eyebrow": "Recording Examples",
  "examples.title": "See what a completed cloud recording looks like.",
  "partner.eyebrow": "Partner Recording Archive",
  "partner.title": "Explore a large archive of recorded livestream videos.",
  "partner.body": "Visit our partner's YouTube archive to see long-form recorded livestream content and the review workflow SaveStream is being built to support.",
  "partner.long": "Long livestream",
  "partner.creator": "Creator archive",
  "partner.review": "Review footage",
  "partner.library": "Recorded library",
  "bottom.title": "Ready to stop missing livestreams?",
  "bottom.body": "Add your channels and let SaveStream record automatically in the cloud.",
  "footer.help": "Help",
  "footer.terms": "Terms",
  "footer.privacy": "Privacy",
  "footer.acceptable": "Acceptable Use",
  "auth.backHome": "Back to SaveStream",
  "auth.welcomeBack": "Welcome back",
  "auth.createAccountTitle": "Create your account",
  "auth.resetTitle": "Reset your password",
  "auth.newPasswordTitle": "Choose a new password",
  "auth.signInBody": "Sign in to continue to your SaveStream workspace.",
  "auth.signUpBody": "Create an account and start monitoring your first TikTok channel.",
  "auth.recoveryBody": "We'll help you recover access to your account.",
  "auth.newUser": "New to SaveStream?",
  "auth.haveAccount": "Already have an account?",
  "auth.continueGoogle": "Continue with Google",
  "auth.continueApple": "Continue with Apple",
  "auth.continueGitHub": "Continue with GitHub",
  "auth.continueEmail": "or continue with email",
  "auth.fullName": "Full name",
  "auth.email": "Email",
  "auth.password": "Password",
  "auth.newPassword": "New password",
  "auth.remember": "Remember me",
  "auth.forgot": "Forgot password?",
  "auth.createAccount": "Create account",
  "auth.sendReset": "Send reset link",
  "auth.resetPassword": "Reset password",
  "auth.signingIn": "Signing in…",
  "auth.creating": "Creating account…",
  "auth.sending": "Sending reset link…",
  "auth.resetting": "Resetting password…",
  "auth.required": "Please complete all required fields.",
  "auth.invalidEmail": "Enter a valid email address.",
  "auth.passwordShort": "Use at least 8 characters for your password.",
  "auth.genericError": "We couldn't continue. Check the form and try again.",
  "auth.termsPrefix": "By creating an account, you agree to the",
  "auth.terms": "Terms of Service",
  "auth.and": "and",
  "auth.privacy": "Privacy Policy",
  "auth.passwordStrength": "Password strength",
  "auth.strengthWeak": "Weak",
  "auth.strengthGood": "Good",
  "auth.strengthStrong": "Strong",
  "auth.ruleLength": "At least 8 characters",
  "auth.ruleNumber": "At least one number",
  "auth.ruleUppercase": "At least one uppercase letter",
  "auth.showPassword": "Show password",
  "auth.hidePassword": "Hide password",
  "auth.hero": "We monitor. We record. You can close the browser.",
  "auth.recordingNow": "Recording now",
  "auth.recordingContinues": "Recording continues on our servers.",
  "status.Recording": "Recording",
  "status.Processing": "Processing",
  "status.Ready": "Ready",
  "status.Waiting": "Waiting",
  "status.Offline": "Offline",
  "status.Paused": "Paused",
  "status.Error": "Error",
} as const;

type MessageKey = keyof typeof en;

const vi: Record<MessageKey, string> = {
  "preferences.language": "Ngôn ngữ",
  "preferences.theme": "Giao diện",
  "preferences.english": "Tiếng Anh",
  "preferences.vietnamese": "Tiếng Việt",
  "theme.system": "Theo hệ thống",
  "theme.light": "Sáng",
  "theme.dark": "Tối",
  "nav.features": "Tính năng",
  "nav.how": "Cách hoạt động",
  "nav.platforms": "Nền tảng",
  "nav.examples": "Video mẫu",
  "nav.pricing": "Bảng giá",
  "nav.signIn": "Đăng nhập",
  "nav.signUp": "Đăng ký",
  "nav.overview": "Tổng quan",
  "nav.channels": "Kênh",
  "nav.recordings": "Bản ghi",
  "nav.usage": "Sử dụng & thanh toán",
  "nav.notifications": "Thông báo",
  "nav.settings": "Cài đặt",
  "nav.help": "Trợ giúp",
  "nav.openMenu": "Mở menu",
  "nav.closeMenu": "Đóng menu",
  "nav.toggleTheme": "Đổi giao diện",
  "nav.plan": "gói",
  "cta.startRecording": "Bắt đầu ghi miễn phí",
  "cta.seeHow": "Xem cách hoạt động",
  "cta.visitPartner": "Xem kênh đối tác",
  "hero.badge": "Tự động ghi trên cloud",
  "hero.title": "Tự động ghi livestream TikTok trên cloud.",
  "hero.body": "Chỉ cần thêm kênh một lần. SaveStream liên tục theo dõi và tự động ghi mọi livestream — kể cả khi máy tính của bạn đang tắt.",
  "hero.noCard": "Không cần thẻ thanh toán.",
  "preview.overview": "Tổng quan",
  "preview.workspace": "Không gian ghi livestream của bạn",
  "preview.addChannel": "Thêm kênh",
  "preview.recordingHours": "Giờ đã ghi",
  "preview.activeChannels": "Kênh đang hoạt động",
  "preview.stored": "Đã lưu",
  "preview.used": "Đã dùng 25%",
  "preview.monitoring": "Đang theo dõi 3 kênh",
  "preview.recordings": "4 bản ghi",
  "preview.activeRecording": "ĐANG GHI",
  "preview.written": "Đã ghi 3,8 GB",
  "how.eyebrow": "Cách hoạt động",
  "how.title": "Thiết lập một lần. Phần còn lại để chúng tôi xử lý.",
  "how.add.title": "Thêm kênh",
  "how.add.body": "Dán username hoặc URL hồ sơ TikTok.",
  "how.monitor.title": "Hệ thống theo dõi",
  "how.monitor.body": "Worker trên cloud liên tục kiểm tra trạng thái kênh.",
  "how.record.title": "Tự động bắt đầu ghi",
  "how.record.body": "Quá trình ghi bắt đầu ngay khi kênh livestream.",
  "how.watch.title": "Xem lại sau",
  "how.watch.body": "Video hoàn tất sẽ xuất hiện trong thư viện của bạn.",
  "features.eyebrow": "Thiết kế dành cho cloud",
  "features.title": "Đóng máy tính. Recording vẫn tiếp tục.",
  "features.body": "Monitoring và recording chạy trên server, không phụ thuộc trình duyệt của bạn.",
  "features.liveDetection": "Tự động phát hiện livestream",
  "features.cloudRecording": "Ghi hoàn toàn trên cloud",
  "features.multiChannel": "Theo dõi nhiều kênh",
  "features.library": "Thư viện bản ghi",
  "features.playback": "Phát video trên trình duyệt",
  "features.downloads": "Tải xuống nhanh",
  "features.usage": "Theo dõi quota sử dụng",
  "features.retention": "Tự động dọn theo thời hạn lưu",
  "platforms.eyebrow": "Nền tảng hỗ trợ",
  "platforms.title": "TikTok Live trước. Douyin sẽ được bổ sung sau.",
  "platforms.body": "MVP tập trung hoàn thiện luồng recording TikTok đáng tin cậy trước khi mở rộng mô hình cloud automation sang Douyin.",
  "platforms.available": "Đang hỗ trợ",
  "platforms.planned": "Dự kiến",
  "platforms.tiktok.body": "Tự động theo dõi, ghi trên server, xử lý, phát lại và tải xuống là luồng cốt lõi của SaveStream MVP.",
  "platforms.douyin.body": "Douyin sẽ được phát triển sau khi TikTok MVP, độ ổn định worker và vòng đời recording đã hoàn thiện.",
  "examples.eyebrow": "Video ghi mẫu",
  "examples.title": "Xem thử một bản ghi cloud hoàn chỉnh trông như thế nào.",
  "partner.eyebrow": "Kho video của đối tác",
  "partner.title": "Khám phá kho lớn các livestream đã được ghi lại.",
  "partner.body": "Xem kho YouTube của đối tác để tham khảo nội dung livestream dài và quy trình review mà SaveStream đang được xây dựng để hỗ trợ.",
  "partner.long": "Livestream dài",
  "partner.creator": "Kho creator",
  "partner.review": "Video review",
  "partner.library": "Thư viện đã ghi",
  "bottom.title": "Sẵn sàng không bỏ lỡ livestream nào nữa?",
  "bottom.body": "Thêm kênh và để SaveStream tự động ghi trên cloud.",
  "footer.help": "Trợ giúp",
  "footer.terms": "Điều khoản",
  "footer.privacy": "Quyền riêng tư",
  "footer.acceptable": "Chính sách sử dụng",
  "auth.backHome": "Quay lại SaveStream",
  "auth.welcomeBack": "Chào mừng trở lại",
  "auth.createAccountTitle": "Tạo tài khoản",
  "auth.resetTitle": "Đặt lại mật khẩu",
  "auth.newPasswordTitle": "Chọn mật khẩu mới",
  "auth.signInBody": "Đăng nhập để tiếp tục vào không gian SaveStream của bạn.",
  "auth.signUpBody": "Tạo tài khoản và bắt đầu theo dõi kênh TikTok đầu tiên.",
  "auth.recoveryBody": "Chúng tôi sẽ giúp bạn lấy lại quyền truy cập tài khoản.",
  "auth.newUser": "Bạn chưa có tài khoản?",
  "auth.haveAccount": "Bạn đã có tài khoản?",
  "auth.continueGoogle": "Tiếp tục với Google",
  "auth.continueApple": "Tiếp tục với Apple",
  "auth.continueGitHub": "Tiếp tục với GitHub",
  "auth.continueEmail": "hoặc tiếp tục bằng email",
  "auth.fullName": "Họ và tên",
  "auth.email": "Email",
  "auth.password": "Mật khẩu",
  "auth.newPassword": "Mật khẩu mới",
  "auth.remember": "Ghi nhớ đăng nhập",
  "auth.forgot": "Quên mật khẩu?",
  "auth.createAccount": "Tạo tài khoản",
  "auth.sendReset": "Gửi liên kết đặt lại",
  "auth.resetPassword": "Đặt lại mật khẩu",
  "auth.signingIn": "Đang đăng nhập…",
  "auth.creating": "Đang tạo tài khoản…",
  "auth.sending": "Đang gửi liên kết…",
  "auth.resetting": "Đang đặt lại mật khẩu…",
  "auth.required": "Vui lòng điền đầy đủ các trường bắt buộc.",
  "auth.invalidEmail": "Vui lòng nhập địa chỉ email hợp lệ.",
  "auth.passwordShort": "Mật khẩu cần có ít nhất 8 ký tự.",
  "auth.genericError": "Không thể tiếp tục. Hãy kiểm tra thông tin và thử lại.",
  "auth.termsPrefix": "Khi tạo tài khoản, bạn đồng ý với",
  "auth.terms": "Điều khoản dịch vụ",
  "auth.and": "và",
  "auth.privacy": "Chính sách quyền riêng tư",
  "auth.passwordStrength": "Độ mạnh mật khẩu",
  "auth.strengthWeak": "Yếu",
  "auth.strengthGood": "Tốt",
  "auth.strengthStrong": "Mạnh",
  "auth.ruleLength": "Ít nhất 8 ký tự",
  "auth.ruleNumber": "Có ít nhất một chữ số",
  "auth.ruleUppercase": "Có ít nhất một chữ in hoa",
  "auth.showPassword": "Hiện mật khẩu",
  "auth.hidePassword": "Ẩn mật khẩu",
  "auth.hero": "Chúng tôi theo dõi. Chúng tôi ghi. Bạn có thể đóng trình duyệt.",
  "auth.recordingNow": "Đang ghi",
  "auth.recordingContinues": "Recording vẫn tiếp tục trên server.",
  "status.Recording": "Đang ghi",
  "status.Processing": "Đang xử lý",
  "status.Ready": "Sẵn sàng",
  "status.Waiting": "Đang chờ",
  "status.Offline": "Ngoại tuyến",
  "status.Paused": "Đã tạm dừng",
  "status.Error": "Lỗi",
};

const messages: Record<Locale, Record<MessageKey, string>> = { en, vi };

interface PreferencesContextValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  theme: ThemePreference;
  setTheme: (theme: ThemePreference) => void;
  resolvedTheme: "light" | "dark";
  t: (key: MessageKey) => string;
}

const PreferencesContext = createContext<PreferencesContextValue | null>(null);

function initialLocale(): Locale {
  if (typeof window === "undefined") return "en";
  const stored = window.localStorage.getItem("savestream.locale");
  if (stored === "en" || stored === "vi") return stored;
  return window.navigator.language.toLowerCase().startsWith("vi") ? "vi" : "en";
}

function initialTheme(): ThemePreference {
  if (typeof window === "undefined") return "system";
  const stored = window.localStorage.getItem("savestream.theme");
  return stored === "light" || stored === "dark" || stored === "system" ? stored : "system";
}

export function PreferencesProvider({ children }: { children: ReactNode }) {
  const [locale, setLocale] = useState<Locale>(initialLocale);
  const [theme, setTheme] = useState<ThemePreference>(initialTheme);
  const [resolvedTheme, setResolvedTheme] = useState<"light" | "dark">("light");

  useEffect(() => {
    document.documentElement.lang = locale === "vi" ? "vi" : "en";
    window.localStorage.setItem("savestream.locale", locale);
  }, [locale]);

  useEffect(() => {
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const applyTheme = () => {
      const next = theme === "system" ? (media.matches ? "dark" : "light") : theme;
      setResolvedTheme(next);
      document.documentElement.classList.toggle("dark", next === "dark");
      document.documentElement.style.colorScheme = next;
    };

    applyTheme();
    window.localStorage.setItem("savestream.theme", theme);
    media.addEventListener("change", applyTheme);
    return () => media.removeEventListener("change", applyTheme);
  }, [theme]);

  const value = useMemo<PreferencesContextValue>(
    () => ({
      locale,
      setLocale,
      theme,
      setTheme,
      resolvedTheme,
      t: (key) => messages[locale][key],
    }),
    [locale, theme, resolvedTheme],
  );

  return <PreferencesContext.Provider value={value}>{children}</PreferencesContext.Provider>;
}

export function usePreferences() {
  const value = useContext(PreferencesContext);
  if (!value) throw new Error("usePreferences must be used inside PreferencesProvider");
  return value;
}

export type { MessageKey };
