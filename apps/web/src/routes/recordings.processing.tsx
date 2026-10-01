import { createFileRoute } from "@tanstack/react-router";
import { RecordingDetailPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/processing")({ head:()=>meta("Processing recording","Track a livestream recording while it is prepared for playback."), component:()=> <RecordingDetailPage state="processing"/> });