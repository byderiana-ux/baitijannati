import type { Metadata, Viewport } from 'next';
import '@fontsource-variable/inter';
import './globals.css';

export const metadata: Metadata = {
  title: 'Baiti Jannati Solution',
  description: 'Ruang kerja operasional Baiti Jannati Solution',
  manifest: '/manifest.webmanifest',
};
export const viewport: Viewport = { themeColor: '#0f5c53' };

export default function Layout({ children }: { children: React.ReactNode }) {
  return <html lang="id"><body>{children}</body></html>;
}
