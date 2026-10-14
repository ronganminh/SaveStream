import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";

import { cn } from "@/lib/utils";

const buttonVariants = cva(
  // Redesign: 44 px default target, 12 px radius, semibold label, accent glow.
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-[12px] border border-transparent text-[15px] font-semibold cursor-pointer transition-[background-color,border-color,box-shadow,filter,transform] active:translate-y-px focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/25 disabled:pointer-events-none disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default:
          "bg-primary text-primary-foreground shadow-glow hover:brightness-110 hover:-translate-y-px",
        destructive: "bg-destructive text-destructive-foreground hover:brightness-110",
        outline: "border-line-strong bg-surface text-foreground hover:border-primary",
        secondary: "bg-surface-2 text-foreground hover:bg-primary-subtle",
        ghost: "text-foreground hover:bg-surface-2",
        link: "h-auto px-0 text-accent-ink underline-offset-4 hover:underline",
      },
      size: {
        default: "min-h-11 px-[18px]",
        sm: "min-h-9 rounded-[10px] px-3 text-sm",
        lg: "min-h-13 rounded-[14px] px-6 text-base",
        icon: "size-11 shrink-0",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        data-slot="button"
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };