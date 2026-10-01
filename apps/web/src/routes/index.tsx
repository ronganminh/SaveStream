import { createFileRoute } from "@tanstack/react-router";
import { LandingPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/")({ head:()=>meta("Automatic TikTok livestream recording","Monitor TikTok channels and record livestreams automatically in the cloud."), component:LandingPage });