export type Row = { id: string; name: string; detail: string; amount: number; status: string; date: string };
export const sections = [
  { label: 'Ruang kerja', items: ['Dashboard', 'CRM', 'Pelanggan', 'Produk'] },
  { label: 'Operasional', items: ['Penjualan', 'Pembelian', 'Impor', 'Inventori', 'Pengiriman'] },
  { label: 'Keuangan', items: ['Faktur', 'Keuangan', 'Akuntansi', 'Laporan'] },
  { label: 'Sistem', items: ['AI Assistant', 'Persetujuan', 'Pengaturan'] },
];
export const samples: Record<string, Row[]> = {
  Penjualan: [
    {id:'SO-2026-084',name:'PT Natura Kosmetika',detail:'Sales Order',amount:24500000,status:'Selesai',date:'2026-11-20'},
    {id:'SO-2026-083',name:'Aluna Beauty Indonesia',detail:'Sales Order',amount:18750000,status:'Diproses',date:'2026-11-19'},
    {id:'QT-2026-102',name:'Seruni Skincare',detail:'Penawaran',amount:12500000,status:'Draft',date:'2026-11-18'},
  ],
  Pembelian: [{id:'PO-2026-041',name:'Guangzhou Packaging Co.',detail:'Purchase Order',amount:36000000,status:'Diproses',date:'2026-11-19'}],
  Faktur: [{id:'INV-2026-112',name:'PT Natura Kosmetika',detail:'Faktur DP',amount:12000000,status:'Jatuh tempo',date:'2026-11-18'}],
  Inventori: [
    {id:'PKG-001',name:'Botol Serum Amber 30 ml',detail:'Gudang Utama',amount:1680,status:'Tersedia',date:'2026-11-20'},
    {id:'PKG-002',name:'Jar Krim Frosted 50 g',detail:'Gudang Utama',amount:42,status:'Stok rendah',date:'2026-11-20'},
    {id:'PKG-003',name:'Botol Pump Airless 15 ml',detail:'Gudang Cadangan',amount:0,status:'Habis',date:'2026-11-19'},
    {id:'PKG-004',name:'Dropper Emas 18 mm',detail:'Gudang Cadangan',amount:980,status:'Tersedia',date:'2026-11-18'},
    {id:'PKG-005',name:'Tube Kosmetik Ivory 100 ml',detail:'Gudang Utama',amount:820,status:'Tersedia',date:'2026-11-17'},
  ],
  Pelanggan: [{id:'CUST-001',name:'PT Natura Kosmetika',detail:'Kosmetik',amount:24500000,status:'Aktif',date:'2026-11-20'},{id:'CUST-002',name:'Aluna Beauty Indonesia',detail:'Skincare',amount:18750000,status:'Aktif',date:'2026-11-19'}],
  CRM: [{id:'LEAD-001',name:'Seruni Skincare',detail:'Referensi pelanggan',amount:12500000,status:'Negosiasi',date:'2026-11-18'}],
  Impor: [{id:'IMP-2026-021',name:'Guangzhou Packaging Co.',detail:'Tiongkok · Laut',amount:36000000,status:'Dalam perjalanan',date:'2026-11-25'}],
  Pengiriman: [{id:'DO-2026-075',name:'PT Natura Kosmetika',detail:'Gudang Utama',amount:250,status:'Diproses',date:'2026-11-20'}],
  Keuangan: [{id:'PAY-2026-034',name:'Aluna Beauty Indonesia',detail:'Penerimaan pembayaran',amount:9500000,status:'Selesai',date:'2026-11-19'}],
  Akuntansi: [{id:'JRN-2026-008',name:'Penerimaan pelanggan',detail:'Jurnal umum',amount:9500000,status:'Draft',date:'2026-11-19'}],
  Persetujuan: [{id:'APR-2026-012',name:'Guangzhou Packaging Co.',detail:'PO-2026-041 · Pembelian',amount:36000000,status:'Menunggu',date:'2026-11-19'}],
};
samples.Produk = samples.Inventori.map((row) => ({...row, detail:'Kemasan kosmetik', amount:0,status:'Aktif'}));

export const money = (value: number) => 'Rp ' + new Intl.NumberFormat('id-ID').format(value);
export const number = (value: number) => new Intl.NumberFormat('id-ID').format(value);
export const dateLabel = (date: string) => date ? new Intl.DateTimeFormat('id-ID',{day:'numeric',month:'short',year:'numeric',timeZone:'UTC'}).format(new Date(date + 'T00:00:00Z')) : '—';
