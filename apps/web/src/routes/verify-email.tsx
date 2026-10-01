import { Outlet, createFileRoute } from "@tanstack/react-router";
export const Route = createFileRoute("/verify-email")({ component:()=> <Outlet/> });