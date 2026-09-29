import { Link } from "@tanstack/react-router";
import { Activity, AlertTriangle, ArrowRight, Bell, Check, Clock3, Cloud, Download, FileVideo, HardDrive, Play, Plus, Radio, Search, Server, ShieldCheck, Trash2, Users, Video } from "lucide-react";
import { useMemo, useState } from "react";
import { AppShell } from "./components/app-shell";
import { AddChannelDialog, MonitoringHealth, OnboardingChecklist } from "./components/p1-experience";
import { Logo, SaveStreamMark } from "./components/brand";
import { PageHeader, Panel, Progress, StatusBadge } from "./components/ui";
import { channels, jobs, notifications, recordings, workers } from "./lib/mock-data";

const button = "inline-flex h-10 items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-400";
const secondaryButton = "inline-flex h-10 items-center justify-center gap-2 rounded-lg border border-[var(--border)] bg-[var(--surface)] px-4 text-sm font-semibold transition hover:bg-[var(--subtle)]";

export function LandingPage() {
  return (
    <div className="min-h-screen bg-[var(--bg)] text-[var(--fg)]">
      <header className="sticky top-0 z-30 border-b border-[var(--border)] bg-[color:var(--bg)]/90 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-7xl items-center px-4 sm:px-6">
          <Logo />
          <nav className="ml-10 hidden items-center gap-7 text-sm text-[var(--muted)] md:flex">
            <a href="#features">Features</a><a href="#how">How it works</a><a href="#examples">Examples</a><Link to="/pricing">Pricing</Link>
          </nav>
          <div className="ml-auto flex items-center gap-2"><Link to="/sign-in" className="hidden px-3 text-sm font-medium sm:block">Sign in</Link><Link to="/sign-up" className={button}>Start recording free</Link></div>
        </div>
      </header>
      <main>
        <section className="border-b border-[var(--border)] px-4 pb-20 pt-24 text-center">
          <span className="inline-flex items-center gap-2 rounded-full border border-[var(--border)] bg-[var(--surface)] px-3 py-1 text-xs text-[var(--muted)]"><Cloud className="size-3 text-indigo-600" />Automatic cloud recording</span>
          <h1 className="mx-auto mt-6 max-w-4xl text-4xl font-semibold tracking-tight sm:text-6xl">Automatic TikTok livestream recording in the cloud.</h1>
          <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-[var(--muted)]">Add a channel once. SaveStream monitors it continuously and automatically records every livestream — even when your computer is offline.</p>
          <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row"><Link to="/sign-up" className={button}>Start for free<ArrowRight className="size-4" /></Link><a href="#how" className={secondaryButton}>See how it works</a></div>
          <p className="mt-3 text-xs text-[var(--muted)]">No credit card required.</p>
          <div className="mx-auto mt-14 max-w-5xl rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-3 shadow-2xl shadow-indigo-950/10">
            <div className="rounded-xl border border-[var(--border)] bg-[var(--bg)] p-5 text-left">
              <div className="flex items-center justify-between"><div><h2 className="font-semibold">Overview</h2><p className="text-xs text-[var(--muted)]">Your recording workspace</p></div><span className={button}><Plus className="size-4" />Add channel</span></div>
              <div className="mt-5 grid gap-px overflow-hidden rounded-lg border border-[var(--border)] bg-[var(--border)] sm:grid-cols-3"><Metric label="Recording hours" value="12.6 / 50 h" detail="25% used" /><Metric label="Active channels" value="3 / 5" detail="3 monitoring" /><Metric label="Stored" value="18.4 GB" detail="4 recordings" /></div>
              <div className="mt-5 rounded-xl border border-red-200 bg-red-50 p-5 dark:border-red-500/20 dark:bg-red-500/5"><div className="flex items-center justify-between"><span className="text-xs font-semibold text-red-600">● ACTIVE RECORDING</span><StatusBadge status="Recording" /></div><div className="mt-5 flex flex-col gap-4 sm:flex-row sm:items-center"><Avatar initials="LS" /><div><b>Lina Studio</b><p className="text-sm text-[var(--muted)]">@linastudio · TikTok</p></div><div className="sm:ml-auto"><p className="font-mono text-2xl font-semibold">01:42:18</p><p className="text-xs text-[var(--muted)]">3.8 GB written</p></div></div></div>
            </div>
          </div>
        </section>
        <section id="how" className="border-b border-[var(--border)] py-20"><div className="mx-auto max-w-6xl px-4"><p className="text-sm font-semibold text-indigo-600">How it works</p><h2 className="mt-2 text-3xl font-semibold">Set it once. We handle the rest.</h2><div className="mt-10 grid gap-px overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--border)] md:grid-cols-4">{[[Plus,"Add a channel","Paste a TikTok username or profile URL."],[Radio,"We monitor it","Cloud workers check the channel continuously."],[Video,"Recording starts","Recording begins automatically when the channel goes live."],[Play,"Watch later","The completed video appears in your library."]].map(([Icon,title,body]) => { const I = Icon as typeof Plus; return <article key={String(title)} className="bg-[var(--surface)] p-6"><I className="size-5 text-indigo-600" /><h3 className="mt-8 font-medium">{String(title)}</h3><p className="mt-2 text-sm leading-6 text-[var(--muted)]">{String(body)}</p></article>; })}</div></div></section>
        <section id="features" className="border-b border-[var(--border)] py-20"><div className="mx-auto grid max-w-6xl gap-12 px-4 md:grid-cols-[.8fr_1.2fr]"><div><p className="text-sm font-semibold text-indigo-600">Cloud by design</p><h2 className="mt-2 text-3xl font-semibold">Close your laptop. Recording continues.</h2><p className="mt-4 text-[var(--muted)]">Monitoring and recording run on our servers, not in your browser.</p></div><div className="grid gap-px overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--border)] sm:grid-cols-2">{["Automatic live detection","Cloud recording","Multiple monitored channels","Recording library","Browser playback","Fast downloads","Usage tracking","Retention cleanup"].map((item) => <div key={item} className="flex items-center gap-3 bg-[var(--surface)] p-4 text-sm"><Check className="size-4 text-emerald-600" />{item}</div>)}</div></div></section>
        <section id="examples" className="border-b border-[var(--border)] py-20"><div className="mx-auto max-w-6xl px-4"><div className="text-center"><p className="text-sm font-semibold text-indigo-600">Recording Examples</p><h2 className="mt-2 text-3xl font-semibold">See what a completed cloud recording looks like.</h2></div><div className="mt-10 grid gap-5 md:grid-cols-3">{recordings.slice(0,3).map((recording) => <article key={recording.id} className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)]"><div className="relative aspect-video bg-gradient-to-br from-slate-950 via-indigo-950 to-violet-900"><SaveStreamMark className="absolute left-1/2 top-1/2 size-14 -translate-x-1/2 -translate-y-1/2 opacity-60" /><span className="absolute bottom-3 right-3 rounded bg-black/70 px-2 py-1 font-mono text-xs text-white">{recording.duration}</span></div><div className="p-5"><div className="flex items-center justify-between"><b>{recording.handle}</b><StatusBadge status="Ready" /></div><p className="mt-2 text-sm text-[var(--muted)]">{recording.date} · {recording.resolution}</p></div></article>)}</div><div className="mt-8 text-center"><Link to="/sign-up" className={button}>Start recording your own livestreams<ArrowRight className="size-4" /></Link></div></div></section>
        <section className="py-20 text-center"><h2 className="text-3xl font-semibold">Ready to stop missing livestreams?</h2><p className="mx-auto mt-3 max-w-xl text-[var(--muted)]">Add your channels and let SaveStream record automatically in the cloud.</p><Link to="/sign-up" className={`${button} mt-7`}>Start for free</Link></section>
      </main>
      <footer className="border-t border-[var(--border)] py-8"><div className="mx-auto flex max-w-7xl flex-col gap-4 px-4 text-sm text-[var(--muted)] sm:flex-row sm:items-center"><Logo /><nav className="sm:ml-auto flex flex-wrap gap-5"><Link to="/pricing">Pricing</Link><Link to="/help">Help</Link><Link to="/terms">Terms</Link><Link to="/privacy">Privacy</Link><Link to="/acceptable-use">Acceptable Use</Link></nav></div></footer>
    </div>
  );
}

function Metric({ label, value, detail }: { label: string; value: string; detail: string }) { return <div className="bg-[var(--surface)] p-5"><p className="text-sm text-[var(--muted)]">{label}</p><p className="mt-2 font-mono text-2xl font-semibold">{value}</p><p className="mt-1 text-xs text-[var(--muted)]">{detail}</p></div>; }
function Avatar({ initials }: { initials: string }) { return <span className="grid size-11 shrink-0 place-items-center rounded-full bg-gradient-to-br from-fuchsia-500 to-rose-400 text-xs font-semibold text-white">{initials}</span>; }

export function OverviewPage() {
  const [addOpen, setAddOpen] = useState(false);
  return (
    <>
      <AppShell>
        <PageHeader
          title="Overview"
          subtitle="Your cloud recording workspace"
          action={<button className={button} onClick={() => setAddOpen(true)}><Plus className="size-4" />Add channel</button>}
        />
        <div className="grid overflow-hidden rounded-xl border border-[var(--border)] sm:grid-cols-2 xl:grid-cols-4">
          <Metric label="Recording hours" value="12.6 / 50 h" detail="25% used · resets Oct 1" />
          <Metric label="Active channels" value="3 / 5" detail="3 currently monitoring" />
          <Metric label="Stored recordings" value="18.4 GB" detail="4 recordings" />
          <Metric label="Download usage" value="24.8 / 100 GB" detail="25% used this month" />
        </div>
        <Panel className="mt-6 overflow-hidden border-red-200">
          <div className="flex items-center justify-between border-b border-red-200 bg-red-50 px-5 py-3 text-red-700">
            <b className="text-xs">● ACTIVE RECORDING</b><StatusBadge status="Recording" />
          </div>
          <div className="grid gap-5 p-5 md:grid-cols-[1fr_auto] md:items-center">
            <div className="flex items-center gap-4">
              <Avatar initials="LS" />
              <div>
                <h2 className="font-semibold">Lina Studio</h2>
                <p className="text-sm text-[var(--muted)]">@linastudio · TikTok</p>
                <p className="mt-3 flex items-center gap-2 text-xs text-[var(--muted)]"><Cloud className="size-4 text-emerald-600" />Recording runs on our servers. You can safely close this page.</p>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-5">
              <div><small className="text-[var(--muted)]">Elapsed</small><p className="font-mono text-2xl font-semibold">01:42:18</p></div>
              <div><small className="text-[var(--muted)]">Written</small><p className="font-mono text-lg font-medium">3.8 GB</p></div>
              <Link to="/recordings/active" className={`${button} col-span-2`}>View recording</Link>
            </div>
          </div>
        </Panel>
        <div className="mt-8 grid gap-8 xl:grid-cols-[1.2fr_.8fr]"><ChannelList compact /><RecordingList compact /></div>
      </AppShell>
      <AddChannelDialog open={addOpen} onClose={() => setAddOpen(false)} />
    </>
  );
}

export function ChannelsPage() {
  const [query, setQuery] = useState("");
  const [addOpen, setAddOpen] = useState(false);
  const filtered = channels.filter((channel) => `${channel.name} ${channel.handle}`.toLowerCase().includes(query.toLowerCase()));
  return (
    <>
      <AppShell>
        <PageHeader
          title="Channels"
          subtitle="Channels are monitored automatically. Recording begins when an enabled channel goes live."
          action={<button className={button} onClick={() => setAddOpen(true)}><Plus className="size-4" />Add channel</button>}
        />
        <div className="mb-5 flex items-center gap-2 border-y border-[var(--border)] bg-[var(--subtle)] p-3">
          <Search className="size-4 text-[var(--muted)]" />
          <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search channels" className="w-full bg-transparent text-sm outline-none" />
        </div>
        <Panel>
          {filtered.map((channel) => (
            <div key={channel.id} className="grid gap-4 border-b border-[var(--border)] p-4 last:border-0 md:grid-cols-[1.4fr_.6fr_1.15fr_.75fr_auto] md:items-center">
              <Link to="/channels/$channelId" params={{channelId:channel.id}} className="flex items-center gap-3">
                <Avatar initials={channel.initials} />
                <span><b className="block">{channel.name}</b><small className="text-[var(--muted)]">{channel.handle}</small></span>
              </Link>
              <span className="text-sm">TikTok</span>
              <MonitoringHealth channel={channel} compact />
              <StatusBadge status={channel.status} />
              <Link to="/channels/$channelId" params={{channelId:channel.id}} className="text-sm font-medium text-indigo-600">View</Link>
            </div>
          ))}
        </Panel>
      </AppShell>
      <AddChannelDialog open={addOpen} onClose={() => setAddOpen(false)} />
    </>
  );
}

function ChannelList({ compact = false }: { compact?: boolean }) {
  return (
    <section>
      <div className="mb-3 flex items-center justify-between"><h2 className="font-semibold">Channel monitoring</h2><Link to="/channels" className="text-sm font-medium text-indigo-600">View all</Link></div>
      <Panel>
        {channels.slice(0, compact ? 3 : channels.length).map((channel) => (
          <div key={channel.id} className="flex items-center gap-3 border-b border-[var(--border)] p-4 last:border-0">
            <Avatar initials={channel.initials} />
            <div className="min-w-0 flex-1">
              <b className="block truncate text-sm">{channel.name}</b>
              <p className="text-xs text-[var(--muted)]">{channel.handle}</p>
              <div className="mt-2"><MonitoringHealth channel={channel} compact /></div>
            </div>
            <StatusBadge status={channel.status} />
          </div>
        ))}
      </Panel>
    </section>
  );
}
function RecordingList({ compact = false }: { compact?: boolean }) { return <section><div className="mb-3 flex items-center justify-between"><h2 className="font-semibold">Recent recordings</h2><Link to="/recordings" className="text-sm font-medium text-indigo-600">View library</Link></div><Panel>{recordings.slice(0,compact?3:recordings.length).map((recording) => <Link key={recording.id} to="/recordings/$recordingId" params={{recordingId:recording.id}} className="flex items-center gap-3 border-b border-[var(--border)] p-4 last:border-0 hover:bg-[var(--subtle)]"><div className="grid aspect-video w-20 place-items-center rounded-lg bg-slate-900 text-white"><FileVideo className="size-5" /></div><div className="min-w-0 flex-1"><b className="block truncate text-sm">{recording.handle}</b><p className="text-xs text-[var(--muted)]">{recording.date} · {recording.duration}</p></div><StatusBadge status={recording.status} /></Link>)}</Panel></section>; }

export function ChannelDetailPage({ channelId }: { channelId: string }) {
  const channel = channels.find((item) => item.id === channelId) ?? channels[0]!;
  return (
    <AppShell>
      <PageHeader title={channel.name} subtitle={channel.handle} action={<button className={secondaryButton}>Monitoring on</button>} />
      <div className="grid gap-6 lg:grid-cols-[.8fr_1.2fr]">
        <Panel className="p-5">
          <div className="flex items-center justify-between"><b>Live status</b><StatusBadge status={channel.status} /></div>
          <p className="mt-7 font-mono text-3xl font-semibold">{channel.status === "Recording" ? "01:42:18" : "Waiting"}</p>
          {channel.status === "Recording" && <Link to="/recordings/active" className={`${button} mt-6`}>View active recording</Link>}
          <div className="mt-6"><MonitoringHealth channel={channel} /></div>
        </Panel>
        <Panel className="p-5">
          <h2 className="font-semibold">Channel statistics</h2>
          <div className="mt-5 grid grid-cols-2 gap-4">
            <Metric label="Recordings" value={String(channel.recordings)} detail="All time" />
            <Metric label="Recorded hours" value="21.6 h" detail="All time" />
            <Metric label="Storage used" value="12.8 GB" detail="Current files" />
            <Metric label="Last livestream" value="Yesterday" detail="20:15" />
          </div>
        </Panel>
      </div>
      <div className="mt-8"><RecordingList /></div>
    </AppShell>
  );
}

export function RecordingsPage() { const [query,setQuery]=useState(""); const filtered=recordings.filter((recording)=>`${recording.handle} ${recording.title}`.toLowerCase().includes(query.toLowerCase())); return <AppShell><PageHeader title="Recordings" subtitle="Watch and download your completed livestream recordings." /><div className="mb-5 flex items-center gap-2 border-y border-[var(--border)] bg-[var(--subtle)] p-3"><Search className="size-4 text-[var(--muted)]" /><input value={query} onChange={(event)=>setQuery(event.target.value)} placeholder="Search recordings" className="w-full bg-transparent text-sm outline-none" /></div><div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">{filtered.map((recording)=><Link key={recording.id} to="/recordings/$recordingId" params={{recordingId:recording.id}} className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--surface)] transition hover:-translate-y-0.5 hover:shadow-lg"><div className="relative aspect-video bg-gradient-to-br from-slate-950 via-indigo-950 to-violet-900"><Video className="absolute left-1/2 top-1/2 size-10 -translate-x-1/2 -translate-y-1/2 text-white/60" /><span className="absolute bottom-3 right-3 rounded bg-black/70 px-2 py-1 font-mono text-xs text-white">{recording.duration}</span></div><div className="p-5"><div className="flex items-center justify-between"><b>{recording.handle}</b><StatusBadge status={recording.status} /></div><p className="mt-2 text-sm text-[var(--muted)]">{recording.date} · {recording.size}</p><p className="mt-3 text-xs text-[var(--muted)]">Expires in {recording.expires}</p></div></Link>)}</div></AppShell>; }

export function RecordingDetailPage({ recordingId, state }: { recordingId?: string; state?: "active"|"processing"|"failed" }) { const recording=recordings.find((item)=>item.id===recordingId) ?? recordings[0]!; const status=state==="active"?"Recording":state==="processing"?"Processing":state==="failed"?"Error":recording.status; return <AppShell><PageHeader title={`${recording.handle} — ${recording.title}`} subtitle={`TikTok · ${recording.date} at ${recording.time}`} action={<div className="flex gap-2"><button className={secondaryButton}><Trash2 className="size-4" />Delete</button><button className={button}><Download className="size-4" />Download video</button></div>} /><div className="relative grid aspect-video max-h-[620px] place-items-center overflow-hidden rounded-xl bg-slate-950 text-white"><div className="absolute inset-0 bg-gradient-to-br from-indigo-950/60 to-transparent" />{status==="Ready"&&<button className="relative grid size-16 place-items-center rounded-full bg-white text-slate-950" aria-label="Play video"><Play className="ml-1 size-6" /></button>}{status==="Recording"&&<div className="relative text-center"><StatusBadge status="Recording" /><p className="mt-5 font-mono text-4xl font-semibold">01:42:18</p><p className="mt-2 text-sm text-white/60">Playback will be available after the livestream ends.</p></div>}{status==="Processing"&&<div className="relative text-center"><span className="mx-auto block size-9 animate-spin rounded-full border-2 border-white/30 border-t-white" /><p className="mt-5 font-medium">Finalizing your recording</p><p className="mt-2 text-sm text-white/60">Recording completed → Processing video → Uploading → Ready</p></div>}{status==="Error"&&<div className="relative max-w-md text-center"><AlertTriangle className="mx-auto size-9 text-red-400" /><p className="mt-4 font-medium">Recording couldn't be completed</p><p className="mt-2 text-sm text-white/60">47 minutes were saved before the stream connection was lost.</p></div>}</div><div className="mt-6 grid gap-4 sm:grid-cols-4"><Metric label="Duration" value={recording.duration} detail="Recorded video" /><Metric label="File size" value={recording.size} detail="Original MP4" /><Metric label="Resolution" value={recording.resolution} detail="Source quality" /><Metric label="Retention" value={recording.expires} detail="Until deletion" /></div>{status==="Recording"&&<div className="mt-6 rounded-xl border border-indigo-200 bg-indigo-50 p-4 text-sm text-indigo-800">Recording runs on our servers. You can safely close this page.</div>}</AppShell>; }

export function UsagePage() { return <AppShell><PageHeader title="Usage" subtitle="Sep 1 – Sep 30, 2026" /><div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4"><Panel className="p-5"><p className="text-sm text-[var(--muted)]">Recording hours</p><p className="mt-2 font-mono text-2xl font-semibold">12.6 / 50</p><div className="mt-4"><Progress value={25} /></div></Panel><Panel className="p-5"><p className="text-sm text-[var(--muted)]">Concurrent limit</p><p className="mt-2 font-mono text-2xl font-semibold">1 / 2</p><p className="mt-2 text-xs text-[var(--muted)]">Active streams</p></Panel><Panel className="p-5"><p className="text-sm text-[var(--muted)]">Download bandwidth</p><p className="mt-2 font-mono text-2xl font-semibold">24.8 / 100 GB</p><div className="mt-4"><Progress value={25} /></div></Panel><Panel className="p-5"><p className="text-sm text-[var(--muted)]">Retention</p><p className="mt-2 font-mono text-2xl font-semibold">30 days</p><p className="mt-2 text-xs text-[var(--muted)]">Pro plan</p></Panel></div><Panel className="mt-6 p-5"><h2 className="font-semibold">Usage by day</h2><div className="mt-8 flex h-48 items-end gap-2">{[28,45,20,62,36,78,48,32,88,55,42,70,30,66,51,82,36,58,44,76,38,60,52,68,45,80,57,72].map((value,index)=><span key={index} className="flex-1 rounded-t bg-indigo-400" style={{height:`${value}%`}} />)}</div></Panel></AppShell>; }

export function BillingPage() { return <AppShell><PageHeader title="Billing" subtitle="Manage your SaveStream subscription." /><div className="grid gap-5 md:grid-cols-2"><Plan name="Free" price="Free" features={["10 minutes recording","1 monitored channel","3-day retention"]} /><Plan name="Pro" price="$9.99 / month" current features={["50 recording hours","5 monitored channels","2 simultaneous recordings","100 GB downloads","30-day retention"]} /></div><Panel className="mt-6 p-5"><h2 className="font-semibold">Billing details</h2><dl className="mt-5 grid gap-4 sm:grid-cols-3"><div><dt className="text-xs text-[var(--muted)]">Payment method</dt><dd className="mt-1 font-medium">Visa ending 4242</dd></div><div><dt className="text-xs text-[var(--muted)]">Next billing date</dt><dd className="mt-1 font-medium">Oct 1, 2026</dd></div><div><dt className="text-xs text-[var(--muted)]">Amount</dt><dd className="mt-1 font-medium">$9.99</dd></div></dl></Panel></AppShell>; }
function Plan({ name, price, features, current=false }: { name:string; price:string; features:string[]; current?:boolean }) { return <Panel className={`p-6 ${current?"border-indigo-500 ring-1 ring-indigo-500":""}`}><div className="flex items-start justify-between"><div><h2 className="text-lg font-semibold">{name}</h2><p className="mt-3 text-3xl font-semibold">{price}</p></div>{current&&<span className="rounded bg-indigo-50 px-2 py-1 text-xs font-medium text-indigo-700">Current plan</span>}</div><ul className="mt-6 space-y-3">{features.map((feature)=><li key={feature} className="flex gap-2 text-sm"><Check className="size-4 text-emerald-600" />{feature}</li>)}</ul><button className={`${current?secondaryButton:button} mt-6 w-full`}>{current?"Manage plan":"Choose plan"}</button></Panel>; }

export function SettingsPage() { return <AppShell><PageHeader title="Settings" subtitle="Manage your account, notifications and security." /><div className="grid gap-5 lg:grid-cols-3"><Panel className="p-5"><h2 className="font-semibold">Account</h2><p className="mt-2 text-sm text-[var(--muted)]">Alex Nguyen<br />alex@savestream.app</p><button className={`${secondaryButton} mt-5`}>Edit account</button></Panel><Panel className="p-5"><h2 className="font-semibold">Notifications</h2><p className="mt-2 text-sm text-[var(--muted)]">Recording and quota email alerts are enabled.</p><button className={`${secondaryButton} mt-5`}>Manage notifications</button></Panel><Panel className="p-5"><h2 className="font-semibold">Security</h2><p className="mt-2 text-sm text-[var(--muted)]">Password and active sessions.</p><button className={`${secondaryButton} mt-5`}>Open security</button></Panel></div></AppShell>; }
export function NotificationsPage() { return <AppShell><PageHeader title="Notifications" subtitle="Recording, processing and quota updates." /><Panel>{notifications.map((notification)=><div key={notification.id} className={`flex gap-3 border-b border-[var(--border)] p-4 last:border-0 ${notification.read?"":"bg-indigo-50/50 dark:bg-indigo-500/5"}`}><span className="mt-2 size-2 rounded-full bg-indigo-600" /><div><b className="text-sm">{notification.title}</b><p className="mt-1 text-sm text-[var(--muted)]">{notification.body}</p><p className="mt-1 text-xs text-[var(--muted)]">{notification.time}</p></div></div>)}</Panel></AppShell>; }

export function AdminSystemPage() { return <AppShell><PageHeader title="Admin · System" subtitle="Internal infrastructure overview." /><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4"><Metric label="Active workers" value="4 / 5" detail="1 offline" /><Metric label="Active recordings" value="2" detail="Cloud jobs" /><Metric label="Queue depth" value="3" detail="Processing queue" /><Metric label="Failed jobs" value="1" detail="Last 24 hours" /></div><Panel className="mt-6 p-5"><h2 className="font-semibold">Service health</h2><div className="mt-5 grid gap-3 sm:grid-cols-2">{["API","Redis","Database","Storage","Monitoring","Workers"].map((service)=><div key={service} className="flex items-center justify-between rounded-lg border border-[var(--border)] p-3"><span>{service}</span><span className="text-sm font-medium text-emerald-600">● Healthy</span></div>)}</div></Panel></AppShell>; }
export function AdminWorkersPage() { return <AppShell><PageHeader title="Admin · Workers" subtitle="Recorder and processor worker activity." /><Panel>{workers.map((worker)=><div key={worker.id} className="grid gap-3 border-b border-[var(--border)] p-4 last:border-0 md:grid-cols-[1.2fr_.8fr_1fr_.5fr_.6fr_.7fr] md:items-center"><b className="font-mono text-sm">{worker.id}</b><span>{worker.status}</span><span className="text-sm text-[var(--muted)]">{worker.currentJob??"—"}</span><span>{worker.cpu}</span><span>{worker.memory}</span><span className="text-sm text-[var(--muted)]">{worker.heartbeat}</span></div>)}</Panel></AppShell>; }
export function AdminJobsPage() { return <AppShell><PageHeader title="Admin · Jobs" subtitle="Recording and processing jobs." /><Panel>{jobs.map((job)=><Link key={job.id} to="/admin/jobs/$jobId" params={{jobId:job.id}} className="grid gap-3 border-b border-[var(--border)] p-4 last:border-0 hover:bg-[var(--subtle)] md:grid-cols-[1fr_1fr_1fr_.8fr_.8fr_.8fr] md:items-center"><b className="font-mono text-sm">{job.id}</b><span>{job.channel}</span><span className="text-sm text-[var(--muted)]">{job.worker}</span><StatusBadge status={job.status} /><span className="font-mono text-sm">{job.duration}</span><span className="text-sm text-[var(--muted)]">{job.heartbeat}</span></Link>)}</Panel></AppShell>; }
export function AdminJobDetailPage({ jobId }: { jobId:string }) { const job=jobs.find((item)=>item.id===jobId)??jobs[0]!; return <AppShell><PageHeader title={job.id} subtitle={`${job.channel} · ${job.worker}`} /><div className="grid gap-5 lg:grid-cols-[.8fr_1.2fr]"><Panel className="p-5"><h2 className="font-semibold">Job metadata</h2><dl className="mt-5 space-y-3 text-sm"><div><dt className="text-[var(--muted)]">Status</dt><dd className="mt-1"><StatusBadge status={job.status} /></dd></div><div><dt className="text-[var(--muted)]">Started</dt><dd>{job.started}</dd></div><div><dt className="text-[var(--muted)]">Duration</dt><dd className="font-mono">{job.duration}</dd></div><div><dt className="text-[var(--muted)]">Retries</dt><dd>{job.retries}</dd></div></dl></Panel><Panel className="p-5"><h2 className="font-semibold">Timeline</h2><ol className="mt-5 space-y-4">{["Live detected","Job queued","Worker assigned","Stream resolved","Recording started","Stream ended","Processing started","Uploaded","Ready"].map((step,index)=><li key={step} className="flex gap-3 text-sm"><span className={`mt-1 size-2 rounded-full ${index<5?"bg-emerald-500":"bg-slate-300"}`} /><span><b className="font-mono text-xs text-[var(--muted)]">13:{22+index}:1{index}</b><br />{step}</span></li>)}</ol></Panel></div></AppShell>; }
export function AdminErrorsPage() { return <AppShell><PageHeader title="Admin · Errors" subtitle="System and worker events." /><Panel>{[["Critical","storage","UPLOAD_FAILED","Multipart upload timed out"],["Error","recorder-01","STREAM_DISCONNECTED","Upstream closed connection"],["Warning","monitor","LIVE_CHECK_FAILED","TikTok live check returned 503"]].map(([severity,service,code,message])=><div key={code} className="grid gap-3 border-b border-[var(--border)] p-4 last:border-0 md:grid-cols-[.7fr_1fr_1.2fr_2fr]"><b className="text-red-600">{severity}</b><span>{service}</span><span className="font-mono text-sm">{code}</span><span className="text-sm text-[var(--muted)]">{message}</span></div>)}</Panel></AppShell>; }

export function AuthPage({ mode }: { mode:"sign-in"|"sign-up"|"forgot"|"reset" }) { const title={"sign-in":"Welcome back","sign-up":"Create your account",forgot:"Reset your password",reset:"Choose a new password"}[mode]; return <div className="grid min-h-screen bg-[var(--bg)] text-[var(--fg)] lg:grid-cols-2"><div className="flex flex-col p-6 sm:p-10"><Logo /><div className="m-auto w-full max-w-sm py-12"><h1 className="text-2xl font-semibold">{title}</h1><p className="mt-2 text-sm text-[var(--muted)]">{mode==="sign-up"?"Start monitoring your first TikTok channel.":"Continue to your SaveStream workspace."}</p><form className="mt-8 space-y-4">{mode==="sign-up"&&<Field label="Full name" placeholder="Alex Nguyen" />}<Field label="Email" placeholder="you@company.com" />{mode!=="forgot"&&<Field label={mode==="reset"?"New password":"Password"} placeholder="••••••••" type="password" />}<Link to={mode==="sign-up"?"/verify-email":mode==="sign-in"?"/overview":"/sign-in"} className={`${button} w-full`}>{mode==="sign-up"?"Create account":mode==="forgot"?"Send reset link":mode==="reset"?"Reset password":"Sign in"}</Link></form>{mode==="sign-up"&&<p className="mt-4 text-xs text-[var(--muted)]">By creating an account, you agree to the Terms and Privacy Policy.</p>}</div></div><div className="hidden place-items-center bg-gradient-to-br from-indigo-50 to-violet-100 lg:grid dark:from-indigo-950/30 dark:to-violet-950/30"><div className="max-w-lg px-10"><SaveStreamMark className="size-14" /><p className="mt-8 text-3xl font-medium leading-tight">We monitor. We record. You can close the browser.</p><p className="mt-8 text-sm text-[var(--muted)]">● Recording @linastudio · 01:42:18</p></div></div></div>; }
function Field({ label, placeholder, type="text" }: { label:string; placeholder:string; type?:string }) { return <label className="block text-sm font-medium">{label}<input type={type} placeholder={placeholder} className="mt-2 h-11 w-full rounded-lg border border-[var(--border)] bg-[var(--surface)] px-3 outline-none focus:ring-2 focus:ring-indigo-400" /></label>; }
export function VerifyEmailPage() { return <SimplePublic title="Check your email" body="We sent a verification link to alex@savestream.app." action="Continue to onboarding" to="/onboarding" />; }
export function OnboardingPage() { return <OnboardingChecklist />; }
export function PricingPage() { return <div className="min-h-screen bg-[var(--bg)] p-6 text-[var(--fg)]"><div className="mx-auto max-w-5xl"><Logo /><div className="py-20 text-center"><h1 className="text-4xl font-semibold">Simple pricing for automatic recording.</h1><p className="mt-4 text-[var(--muted)]">Start free and upgrade when you need more recording hours.</p></div><div className="grid gap-5 md:grid-cols-2"><Plan name="Free" price="Free" features={["10 minutes recording","1 monitored channel","3-day retention"]} /><Plan name="Pro" price="$9.99 / month" features={["50 recording hours","5 monitored channels","100 GB downloads","30-day retention"]} /></div></div></div>; }
export function HelpPage() { return <AppShell><PageHeader title="Help" subtitle="Learn how SaveStream monitoring and cloud recording work." /><div className="grid gap-5 md:grid-cols-2">{["Getting started","Cloud monitoring","Recording lifecycle","Quotas and retention","Failed recording troubleshooting","Contact support"].map((item)=><Panel key={item} className="p-5"><h2 className="font-semibold">{item}</h2><p className="mt-2 text-sm text-[var(--muted)]">Guidance for using SaveStream will live here as backend behavior is implemented.</p></Panel>)}</div></AppShell>; }
export function StatusPage() { return <SimplePublic title="SaveStream status" body="API, monitoring, recording workers, processing and storage are operational in this frontend prototype." action="Go home" to="/" />; }
export function LegalPage({ title }: { title:string }) { return <div className="min-h-screen bg-[var(--bg)] p-6 text-[var(--fg)]"><article className="mx-auto max-w-3xl"><Logo /><h1 className="mt-16 text-4xl font-semibold">{title}</h1><p className="mt-6 leading-7 text-[var(--muted)]">This is placeholder product copy and requires legal review before launch. Users are responsible for ensuring they have the rights and authorization required for content they choose to record and archive. Recordings may expire according to the active subscription's retention period.</p></article></div>; }
function SimplePublic({ title, body, action, to }: { title:string; body:string; action:string; to:string }) { return <div className="grid min-h-screen place-items-center bg-[var(--bg)] p-6 text-[var(--fg)]"><div className="w-full max-w-lg rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-8 text-center"><SaveStreamMark className="mx-auto size-14" /><h1 className="mt-6 text-2xl font-semibold">{title}</h1><p className="mt-3 text-sm leading-6 text-[var(--muted)]">{body}</p><Link to={to} className={`${button} mt-7`}>{action}</Link></div></div>; }
