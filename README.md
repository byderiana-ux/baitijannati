# Baiti Jannati Solution

Demo interaktif untuk distributor kemasan kosmetik. Antarmuka berbahasa Indonesia dan memakai data contoh untuk dashboard dan modul operasional.

## Menjalankan aplikasi

Jalankan npm ci lalu npm run dev. Server pengembangan memakai port 3000. Untuk memeriksa build produksi, jalankan npm run build lalu npm run start.

Draft dan pengaturan demo disimpan di browser. Angka KPI dan grafik dashboard menggunakan data ilustratif. Pencarian, filter, urutan inventori, detail dokumen, dan ekspor CSV tersedia untuk data demo.

## Basis data

supabase/migrations/20261120000000_baseline.sql menyimpan skema awal yang dilampirkan. Antarmuka demo belum terhubung ke Supabase. Skema memerlukan tinjauan izin dan kebijakan RLS, mesin posting transaksional, serta pengujian sebelum dipasang di lingkungan produksi.
