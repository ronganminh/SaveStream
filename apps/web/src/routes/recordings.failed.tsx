import { createFileRoute } from "@tanstack/react-router";
import { RecordingDetailPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/failed")({ head:()=>meta("Failed recording","Review details and partial output from an interrupted recording."), component:()=> <RecordingDetailPage state="failed"/> });