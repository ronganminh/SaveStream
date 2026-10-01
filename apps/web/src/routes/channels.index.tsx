import { createFileRoute } from "@tanstack/react-router";
import { ChannelsPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/channels/")({ head:()=>meta("Channels","Manage authorized TikTok channels and automatic monitoring."), component:ChannelsPage });