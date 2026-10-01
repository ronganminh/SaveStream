import { createFileRoute } from "@tanstack/react-router";
import { RecordingsPage, meta } from "@/components/app-pages";
export const Route = createFileRoute("/recordings/")({ head:()=>meta("Recordings","Watch and download completed livestream recordings."), component:RecordingsPage });