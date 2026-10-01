import { createContext, useContext, useMemo, useState, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import type { AsyncScreenState, SupportError } from "@/domain/models";
import { createSupportReference } from "@/domain/models";
import type { SaveStreamRepository } from "@/data/repository";
import { mockRepository } from "@/data/mock-repository";

const RepositoryContext = createContext<SaveStreamRepository>(mockRepository);

export function RepositoryProvider({
  children,
  repository = mockRepository,
}: {
  children: ReactNode;
  repository?: SaveStreamRepository;
}) {
  return <RepositoryContext.Provider value={repository}>{children}</RepositoryContext.Provider>;
}

export function useRepository() {
  return useContext(RepositoryContext);
}

type ResourceName = "channels" | "channel" | "recordings" | "recording" | "usage";

function readInitialFixtureState(resource: ResourceName): AsyncScreenState {
  if (typeof window === "undefined") return "success";
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get(`fixture_${resource}`) as AsyncScreenState | null;
  if (
    fromQuery &&
    ["idle", "loading", "success", "empty", "error", "retrying", "offline"].includes(fromQuery)
  ) {
    return fromQuery;
  }
  return "success";
}

function useFixtureScreenState(resource: ResourceName) {
  const [fixtureState, setFixtureState] = useState<AsyncScreenState>(() =>
    readInitialFixtureState(resource),
  );
  return [fixtureState, setFixtureState] as const;
}

function fixtureError(state: AsyncScreenState): SupportError | null {
  if (state !== "error" && state !== "offline") return null;
  return {
    title: state === "offline" ? "You’re offline" : "We couldn’t load this screen",
    body:
      state === "offline"
        ? "Reconnect to the internet and try again."
        : "Try again. If the problem continues, share the reference with support.",
    referenceId: createSupportReference(state === "offline" ? "OFF" : "REQ"),
    retryable: true,
  };
}

function resolveScreenState(
  fixture: AsyncScreenState,
  query: { isLoading: boolean; isError: boolean; isFetching: boolean },
): AsyncScreenState {
  if (fixture !== "success") return fixture;
  if (query.isLoading) return "loading";
  if (query.isError) return "error";
  if (query.isFetching) return "retrying";
  return "success";
}

export const asyncFixtureOptions = [
  { value: "success", label: "Success" },
  { value: "loading", label: "Loading" },
  { value: "empty", label: "Empty" },
  { value: "error", label: "Error" },
  { value: "retrying", label: "Retrying" },
  { value: "offline", label: "Offline" },
  { value: "idle", label: "Idle" },
] as const;

export function useChannelsResource() {
  const repository = useRepository();
  const [fixtureState, setFixtureState] = useFixtureScreenState("channels");
  const query = useQuery({ queryKey: ["repository", "channels"], queryFn: () => repository.listChannels() });
  const screenState = resolveScreenState(fixtureState, query);
  const data = screenState === "empty" || screenState === "idle" ? [] : query.data ?? [];
  return {
    data,
    screenState,
    error: fixtureError(screenState),
    retry: () => query.refetch(),
    setFixtureState,
  };
}

export function useChannelResource(id?: string) {
  const repository = useRepository();
  const [fixtureState, setFixtureState] = useFixtureScreenState("channel");
  const query = useQuery({
    queryKey: ["repository", "channel", id],
    queryFn: () => (id ? repository.getChannel(id) : Promise.resolve(null)),
  });
  const screenState = resolveScreenState(fixtureState, query);
  return {
    data: screenState === "empty" || screenState === "idle" ? null : query.data ?? null,
    screenState,
    error: fixtureError(screenState),
    retry: () => query.refetch(),
    setFixtureState,
  };
}

export function useRecordingsResource() {
  const repository = useRepository();
  const [fixtureState, setFixtureState] = useFixtureScreenState("recordings");
  const query = useQuery({
    queryKey: ["repository", "recordings"],
    queryFn: () => repository.listRecordings(),
  });
  const screenState = resolveScreenState(fixtureState, query);
  const data = screenState === "empty" || screenState === "idle" ? [] : query.data ?? [];
  return {
    data,
    screenState,
    error: fixtureError(screenState),
    retry: () => query.refetch(),
    setFixtureState,
  };
}

export function useRecordingResource(id?: string) {
  const repository = useRepository();
  const [fixtureState, setFixtureState] = useFixtureScreenState("recording");
  const query = useQuery({
    queryKey: ["repository", "recording", id],
    queryFn: () => (id ? repository.getRecording(id) : Promise.resolve(null)),
  });
  const screenState = resolveScreenState(fixtureState, query);
  return {
    data: screenState === "empty" || screenState === "idle" ? null : query.data ?? null,
    screenState,
    error: fixtureError(screenState),
    retry: () => query.refetch(),
    setFixtureState,
  };
}

export function useUsageResource() {
  const repository = useRepository();
  const [fixtureState, setFixtureState] = useFixtureScreenState("usage");
  const query = useQuery({ queryKey: ["repository", "usage"], queryFn: () => repository.getUsage() });
  const screenState = resolveScreenState(fixtureState, query);
  return {
    data: query.data ?? null,
    screenState,
    error: fixtureError(screenState),
    retry: () => query.refetch(),
    setFixtureState,
  };
}

export function useRepositoryActions() {
  const repository = useRepository();
  return useMemo(
    () => ({
      lookupChannel: repository.lookupChannel.bind(repository),
      addChannel: repository.addChannel.bind(repository),
      retryRecordingProcessing: repository.retryRecordingProcessing.bind(repository),
      prepareDownload: repository.prepareDownload.bind(repository),
    }),
    [repository],
  );
}
