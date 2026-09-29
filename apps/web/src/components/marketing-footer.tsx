import { Link } from "@tanstack/react-router";
import { ArrowUpRight } from "lucide-react";
import { Logo } from "./brand";
import { usePreferences } from "../lib/preferences";

function scrollToSection(id: string) {
  document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
}

export function MarketingFooter() {
  const { locale } = usePreferences();
  const copy =
    locale === "vi"
      ? {
          description:
            "Tự động theo dõi và ghi livestream TikTok trên cloud, với playback, download và thư viện recording tập trung. Douyin đang được lên kế hoạch.",
          product: "Sản phẩm",
          resources: "Tài nguyên",
          platforms: "Nền tảng",
          company: "SaveStream",
          legal: "Pháp lý",
          features: "Tính năng",
          how: "Cách hoạt động",
          pricing: "Bảng giá",
          examples: "Video ghi mẫu",
          help: "Trợ giúp",
          status: "Trạng thái hệ thống",
          tiktok: "TikTok Live Recorder",
          douyin: "Douyin Live Recorder",
          partner: "Kho recording đối tác",
          signIn: "Đăng nhập",
          signUp: "Tạo tài khoản",
          privacy: "Quyền riêng tư",
          terms: "Điều khoản",
          acceptable: "Chính sách sử dụng",
          rights: "Bảo lưu mọi quyền.",
          available: "Đang hỗ trợ",
          planned: "Dự kiến",
        }
      : {
          description:
            "Automatic TikTok livestream monitoring and cloud recording with playback, downloads and a centralized recording library. Douyin support is planned.",
          product: "Product",
          resources: "Resources",
          platforms: "Platforms",
          company: "SaveStream",
          legal: "Legal",
          features: "Features",
          how: "How it works",
          pricing: "Pricing",
          examples: "Recording Examples",
          help: "Help center",
          status: "System status",
          tiktok: "TikTok Live Recorder",
          douyin: "Douyin Live Recorder",
          partner: "Partner recording archive",
          signIn: "Sign in",
          signUp: "Create account",
          privacy: "Privacy",
          terms: "Terms",
          acceptable: "Acceptable Use",
          rights: "All rights reserved.",
          available: "Available",
          planned: "Planned",
        };

  const footerLink =
    "block w-fit text-sm text-[var(--muted)] transition hover:text-[var(--fg)] focus:outline-none focus-visible:text-indigo-600";

  return (
    <footer className="border-t border-[var(--border)] bg-[var(--surface)]">
      <div className="mx-auto max-w-[1540px] px-4 py-12 sm:px-6 sm:py-14 lg:px-8 lg:py-16">
        <div className="grid gap-10 sm:grid-cols-2 lg:grid-cols-[1.3fr_.75fr_.9fr_.95fr_.85fr_.8fr] lg:gap-8 xl:gap-12">
          <div className="sm:col-span-2 lg:col-span-1">
            <Logo />
            <p className="mt-5 max-w-xs text-sm leading-6 text-[var(--muted)]">{copy.description}</p>
          </div>

          <FooterColumn title={copy.product}>
            <button type="button" className={footerLink} onClick={() => scrollToSection("features")}>{copy.features}</button>
            <button type="button" className={footerLink} onClick={() => scrollToSection("how")}>{copy.how}</button>
            <Link to="/pricing" className={footerLink}>{copy.pricing}</Link>
          </FooterColumn>

          <FooterColumn title={copy.resources}>
            <button type="button" className={footerLink} onClick={() => scrollToSection("examples")}>{copy.examples}</button>
            <Link to="/help" className={footerLink}>{copy.help}</Link>
            <Link to="/status" className={footerLink}>{copy.status}</Link>
          </FooterColumn>

          <FooterColumn title={copy.platforms}>
            <button type="button" className={footerLink} onClick={() => scrollToSection("platforms")}>
              <span className="flex items-center gap-2">
                {copy.tiktok}
                <span className="rounded-full bg-emerald-50 px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-emerald-700 dark:bg-emerald-500/10 dark:text-emerald-300">
                  {copy.available}
                </span>
              </span>
            </button>
            <button type="button" className={footerLink} onClick={() => scrollToSection("platforms")}>
              <span className="flex items-center gap-2">
                {copy.douyin}
                <span className="rounded-full bg-amber-50 px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide text-amber-700 dark:bg-amber-500/10 dark:text-amber-300">
                  {copy.planned}
                </span>
              </span>
            </button>
          </FooterColumn>

          <FooterColumn title={copy.company}>
            <button type="button" className={footerLink} onClick={() => scrollToSection("partner")}>{copy.partner}</button>
            <Link to="/sign-in" className={footerLink}>{copy.signIn}</Link>
            <Link to="/sign-up" className={footerLink}>{copy.signUp}</Link>
          </FooterColumn>

          <FooterColumn title={copy.legal}>
            <Link to="/privacy" className={footerLink}>{copy.privacy}</Link>
            <Link to="/terms" className={footerLink}>{copy.terms}</Link>
            <Link to="/acceptable-use" className={footerLink}>{copy.acceptable}</Link>
          </FooterColumn>
        </div>

        <div className="mt-12 flex flex-col gap-4 border-t border-[var(--border)] pt-6 text-xs text-[var(--muted)] sm:flex-row sm:items-center sm:justify-between">
          <p>© {new Date().getFullYear()} SaveStream. {copy.rights}</p>
          <a
            href="https://www.youtube.com/channel/UCUkhUF-GUS22KWBFEcD2fEw"
            target="_blank"
            rel="noreferrer"
            className="inline-flex w-fit items-center gap-1.5 font-medium transition hover:text-[var(--fg)]"
          >
            {copy.partner} <ArrowUpRight className="size-3.5" />
          </a>
        </div>
      </div>
    </footer>
  );
}

function FooterColumn({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <nav aria-label={title}>
      <h2 className="text-sm font-semibold text-[var(--fg)]">{title}</h2>
      <div className="mt-4 space-y-3">{children}</div>
    </nav>
  );
}
