import { createFileRoute } from "@tanstack/react-router";
import { RecordingDetailPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/active")({ head:()=>meta("Active recording","Follow a livestream recording running securely in the cloud."), component:()=> <RecordingDetailPage state="active"/> });