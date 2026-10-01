import { createFileRoute } from "@tanstack/react-router";
import { ChannelDetailPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/channels/$id")({ head:()=>meta("Channel details","Review channel monitoring status, activity, and recording history."), component:ChannelDetailPage });