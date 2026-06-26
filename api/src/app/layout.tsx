import type { ReactNode } from "react";

export const metadata = {
  title: "DAAS API",
  description: "Furniture Factory Management API",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
