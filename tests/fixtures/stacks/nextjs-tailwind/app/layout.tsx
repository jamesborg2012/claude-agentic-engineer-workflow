import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-white text-slate-900">
        {children}
        <footer className="border-t border-slate-200 p-6 text-sm text-slate-600">
          <p>Fixture Daily</p>
          <nav className="flex gap-4">
            <a href="/about">About</a>
            <a href="/contact">Contact</a>
          </nav>
          <p>&copy; 2026 Fixture Daily</p>
        </footer>
      </body>
    </html>
  );
}
