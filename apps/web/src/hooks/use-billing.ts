import { useEffect } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";

import { ApiError } from "@/api/errors";
import type { CheckoutResponse, PaymentStatusValue } from "@/api/types";
import { domainQueryKeys, usePaymentOrderData } from "@/hooks/use-domain-data";
import { billingCheckoutEnabled } from "@/lib/app-config";
import { repositories } from "@/repositories";

export type BillingCheckoutInput =
  | { packageId: string; orderId?: never }
  | { packageId?: never; orderId: string };

const creditChangingStatuses = new Set<PaymentStatusValue>([
  "paid",
  "partially_refunded",
  "refunded",
]);

export function isAwaitingPaymentConfirmation(status: PaymentStatusValue) {
  return status === "created" || status === "pending";
}

export function isTerminalPaymentStatus(status: PaymentStatusValue) {
  return !isAwaitingPaymentConfirmation(status);
}

function idempotencyKey() {
  if (!globalThis.crypto?.randomUUID) {
    throw new Error("Secure checkout requires UUID support in this browser.");
  }
  return globalThis.crypto.randomUUID();
}

function billingReturnUrl(orderId: string) {
  if (typeof window === "undefined") {
    throw new Error("Hosted checkout can only start in the browser.");
  }
  const url = new URL("/billing/success", window.location.origin);
  url.searchParams.set("order_id", orderId);
  return url.toString();
}

function validatedCheckoutUrl(value: string) {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error("The payment provider returned an invalid checkout URL.");
  }
  if (parsed.protocol !== "https:") {
    throw new Error("Hosted checkout must use HTTPS.");
  }
  return parsed.toString();
}

export function useBillingCheckoutMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    retry: false,
    mutationFn: async (input: BillingCheckoutInput): Promise<CheckoutResponse> => {
      if (!billingCheckoutEnabled) {
        throw new Error("Hosted checkout is not enabled for this deployment.");
      }

      const order = input.orderId
        ? await repositories.billing.getPaymentOrder(input.orderId)
        : await repositories.billing.createPaymentOrder(
            input.packageId,
            idempotencyKey(),
          );

      if (!isAwaitingPaymentConfirmation(order.status)) {
        throw new Error(
          `Payment order ${order.id} cannot open checkout from status ${order.status}.`,
        );
      }

      const checkout = await repositories.billing.createCheckout(
        order.id,
        billingReturnUrl(order.id),
        idempotencyKey(),
      );

      validatedCheckoutUrl(checkout.checkout_url);
      return checkout;
    },
    onSuccess: async (checkout) => {
      queryClient.setQueryData(
        domainQueryKeys.paymentOrder(checkout.payment_order.id),
        checkout.payment_order,
      );
      await queryClient.invalidateQueries({ queryKey: domainQueryKeys.paymentOrders });
    },
  });
}

export function useBillingReturnOrder(orderId: string | null | undefined) {
  const queryClient = useQueryClient();
  const result = usePaymentOrderData(orderId);

  useEffect(() => {
    const status = result.query.data?.status;
    if (!status || !creditChangingStatuses.has(status)) return;

    void Promise.all([
      queryClient.invalidateQueries({ queryKey: domainQueryKeys.creditBalance }),
      queryClient.invalidateQueries({ queryKey: domainQueryKeys.creditTransactions }),
      queryClient.invalidateQueries({ queryKey: domainQueryKeys.creditReservations }),
      queryClient.invalidateQueries({ queryKey: domainQueryKeys.paymentOrders }),
    ]);
  }, [queryClient, result.query.data?.status]);

  return result;
}

export function billingActionErrorMessage(error: unknown): string {
  if (!(error instanceof ApiError)) {
    return error instanceof Error
      ? error.message
      : "The billing action could not be completed.";
  }
  if (error.status === 0) {
    return "Unable to reach SaveStream. Check your connection and try again.";
  }
  if (error.code === "PAYMENT_FAILED") {
    return error.serverMessage || "The payment provider could not start checkout.";
  }
  if (error.code === "IDEMPOTENCY_KEY_REUSED") {
    return "This checkout attempt could not be safely replayed. Start a new purchase.";
  }
  if (error.status >= 500 || error.retryable) {
    return "Billing is temporarily unavailable. Please try again.";
  }
  return error.serverMessage || "The billing action could not be completed.";
}
