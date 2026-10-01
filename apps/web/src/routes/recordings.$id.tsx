import { createFileRoute } from "@tanstack/react-router";
import { RecordingDetailPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/$id")({ head:()=>meta("Recording details","Play, download, and manage a completed livestream recording."), component:RecordingDetailPage });