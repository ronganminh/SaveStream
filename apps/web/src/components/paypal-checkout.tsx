import { useEffect, useRef, useState } from "react";

import { paypalClientId } from "@/lib/app-config";

interface PayPalApproveData {
  orderID: string;
}

interface PayPalButtonsOptions {
  style?: {
    layout?: "vertical" | "horizontal";
    shape?: "rect" | "pill";
    label?: "paypal" | "checkout" | "buynow" | "pay";
  };
  createOrder: () => string | Promise<string>;
  onApprove: (data: PayPalApproveData) => void | Promise<void>;
  onCancel?: () => void;
  onError?: (error: unknown) => void;
}

interface PayPalButtonsInstance {
  render: (container: HTMLElement) => Promise<void>;
  close?: () => Promise<void> | void;
}

interface PayPalNamespace {
  Buttons: (options: PayPalButtonsOptions) => PayPalButtonsInstance;
}

declare global {
  interface Window {
    paypal?: PayPalNamespace;
  }
}

let sdkPromise: Promise<PayPalNamespace> | null = null;

function loadPayPalSdk(): Promise<PayPalNamespace> {
  if (typeof window === "undefined") {
    return Promise.reject(new Error("PayPal checkout can only run in the browser."));
  }
  if (window.paypal) return Promise.resolve(window.paypal);
  if (!paypalClientId) {
    return Promise.reject(new Error("PayPal checkout is not configured yet."));
  }
  if (sdkPromise) return sdkPromise;

  sdkPromise = new Promise<PayPalNamespace>((resolve, reject) => {
    const script = document.createElement("script");
    const query = new URLSearchParams({
      "client-id": paypalClientId,
      components: "buttons",
      currency: "USD",
      intent: "capture",
      commit: "true",
    });
    script.src = `https://www.paypal.com/sdk/js?${query.toString()}`;
    script.async = true;
    script.dataset["savestreamPaypalSdk"] = "true";
    script.onload = () => {
      if (window.paypal) resolve(window.paypal);
      else reject(new Error("PayPal SDK loaded without the Buttons API."));
    };
    script.onerror = () => reject(new Error("Could not load the PayPal checkout SDK."));
    document.head.appendChild(script);
  }).catch((error) => {
    sdkPromise = null;
    throw error;
  });

  return sdkPromise;
}

export function PayPalCheckoutButtons({
  providerOrderId,
  onApprove,
  onCancel,
  onError,
}: {
  providerOrderId: string;
  onApprove: (orderId: string) => Promise<void>;
  onCancel: () => void;
  onError: (error: unknown) => void;
}) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const onApproveRef = useRef(onApprove);
  const onCancelRef = useRef(onCancel);
  const onErrorRef = useRef(onError);
  const [loading, setLoading] = useState(true);
  onApproveRef.current = onApprove;
  onCancelRef.current = onCancel;
  onErrorRef.current = onError;

  useEffect(() => {
    let cancelled = false;
    let buttons: PayPalButtonsInstance | null = null;

    void loadPayPalSdk()
      .then(async (paypal) => {
        if (cancelled || !containerRef.current) return;
        containerRef.current.replaceChildren();
        buttons = paypal.Buttons({
          style: { layout: "vertical", shape: "rect", label: "paypal" },
          createOrder: () => providerOrderId,
          onApprove: async (data) => {
            if (data.orderID !== providerOrderId) {
              throw new Error("PayPal returned an unexpected order ID.");
            }
            await onApproveRef.current(data.orderID);
          },
          onCancel: () => onCancelRef.current(),
          onError: (error) => onErrorRef.current(error),
        });
        await buttons.render(containerRef.current);
        if (!cancelled) setLoading(false);
      })
      .catch((error) => {
        if (!cancelled) {
          setLoading(false);
          onErrorRef.current(error);
        }
      });

    return () => {
      cancelled = true;
      const close = buttons?.close;
      if (close) void close.call(buttons);
    };
  }, [providerOrderId]);

  return (
    <div>
      {loading ? (
        <p className="mb-3 text-sm text-muted-foreground">Loading secure PayPal checkout…</p>
      ) : null}
      <div ref={containerRef} aria-busy={loading} />
    </div>
  );
}
