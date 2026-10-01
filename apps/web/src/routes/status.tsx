import { createFileRoute } from "@tanstack/react-router";
import { meta } from "@/components/app-pages";
import { StatusPage } from "@/components/app-pages-more";
export const Route = createFileRoute("/status")({ head:()=>meta("System status","Live status of SaveStream monitoring, recording, processing, and storage."), component:StatusPage });