import { createFileRoute } from "@tanstack/react-router";

import { publicMeta } from "@/components/app-pages";
import { DeleteAccountPage } from "@/components/public/delete-account";

export const Route = createFileRoute("/delete-account")({
  head: () =>
    publicMeta(
      "/delete-account",
      "Delete your account",
      "Delete your SaveStream account and personal data, in the app or on the web.",
    ),
  component: DeleteAccountPage,
});
