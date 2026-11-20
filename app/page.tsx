'use client';

import { useEffect, useState, type FormEvent } from 'react';
import {
  Activity, ArrowDownRight, ArrowDownToLine, ArrowRight, ArrowUpRight, Bell, Boxes, CalendarDays, ChartNoAxesCombined, Check,
  ChevronDown, ChevronLeft, ChevronRight, CircleHelp, ClipboardCheck, FileText, LayoutDashboard, Menu, Package,
  PanelLeftClose, Plus, Search, Settings, Ship, ShoppingBag, ShoppingCart, Sparkles, Truck, Users, Wallet, X, BookOpen, Building2,
} from 'lucide-react';
import { dateLabel, money, number, samples, sections, type Row } from './data';

const icons = [LayoutDashboard, Activity, Users, Package, ShoppingCart, ShoppingBag, Ship, Boxes, Truck, FileText, Wallet, BookOpen, ChartNoAxesCombined, Sparkles, ClipboardCheck, Settings];
const modules = sections.flatMap(section => section.items);
const descriptions: Record<string,string> = {
  CRM:'Kelola prospek dan aktivitas penjualan.', Pelanggan:'Kelola data dan riwayat pelanggan.',
  Produk:'Kelola katalog dan SKU kemasan kosmetik.', Penjualan:'Pantau penawaran dan pesanan pelanggan.',
  Pembelian:'Pantau pesanan pembelian dan pemasok.', Impor:'Lacak pengiriman dan biaya impor.',
  Inventori:'Pantau stok kemasan di seluruh gudang.', Pengiriman:'Pantau pesanan pengiriman pelanggan.',
  Faktur:'Kelola faktur DP, parsial, dan final.', Keuangan:'Pantau penerimaan dan pengeluaran.',
  Akuntansi:'Tinjau jurnal dan aktivitas pembukuan.', Laporan:'Tinjau dan ekspor ringkasan operasional.',
  Persetujuan:'Tinjau dokumen yang menunggu keputusan.', 'AI Assistant':'Tinjau saran operasional dari data demo.', Pengaturan:'Atur preferensi ruang kerja demo.',
};
const kpis = [
  {title:'Total Pendapatan',value:'Rp 284,5 jt',change:'+12,8%',icon:Wallet,color:'emerald',page:'Keuangan'},
  {title:'Pesanan Penjualan',value:'84',change:'+8,2%',icon:ShoppingBag,color:'mint',page:'Penjualan'},
  {title:'SKU Aktif',value:'326',change:'+4,5%',icon:Boxes,color:'gold',page:'Inventori'},
  {title:'Piutang Usaha',value:'Rp 67,2 jt',change:'−3,1%',icon:FileText,color:'blue',page:'Faktur'},
];
const periods = ['6 bulan terakhir','3 bulan terakhir','Bulan ini'];
const months = ['Jun','Jul','Agu','Sep','Okt','Nov'];
const revenues = [142, 177, 156, 221, 252, 284.5];
const costs = [93, 115, 104, 139, 148, 173];
const units = ['Inventori','Pengiriman','Produk'];
const tones: Record<string,string> = { Selesai:'green',Aktif:'green',Tersedia:'green',Disetujui:'green',Diproses:'blue', 'Dalam perjalanan':'blue',Menunggu:'amber','Stok rendah':'amber','Jatuh tempo':'red',Habis:'red',Ditolak:'red' };
const addable = ['CRM','Pelanggan','Produk','Penjualan','Pembelian','Impor','Pengiriman','Faktur','Keuangan','Akuntansi'];
const alerts = ['2 SKU perlu perhatian di Inventori','PO-2026-041 menunggu persetujuan','INV-2026-112 telah jatuh tempo'];

export default function Home() {
  const [active,setActive] = useState('Dashboard');
  const [records,setRecords] = useState(samples);
  const [ready,setReady] = useState(false);
  const [collapsed,setCollapsed] = useState(false);
  const [mobile,setMobile] = useState(false);
  const [period,setPeriod] = useState(periods[0]);
  const [menu,setMenu] = useState('');
  const [modal,setModal] = useState('');
  const [entry,setEntry] = useState<Row | null>(null);
  const [target,setTarget] = useState('Penjualan');
  const [query,setQuery] = useState('');
  const [globalQuery,setGlobalQuery] = useState('');
  const [filter,setFilter] = useState('');
  const [warehouse,setWarehouse] = useState('');
  const [sort,setSort] = useState('');
  const [page,setPage] = useState(1);
  const [toast,setToast] = useState('');
  const [read,setRead] = useState(false);
  const [hover,setHover] = useState<number | null>(null);
  const [company,setCompany] = useState('Baiti Jannati Solution');

  useEffect(() => {
    try {
      const cached = localStorage.getItem('baiti-records-v1');
      if (cached) setRecords({...samples,...JSON.parse(cached)});
      const saved = localStorage.getItem('baiti-company');
      if (saved) setCompany(saved);
      const hash = decodeURIComponent(location.hash.slice(1));
      if (modules.includes(hash)) setActive(hash);
    } catch {}
    setReady(true);
    if (process.env.NODE_ENV === 'production' && 'serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {
        // The workspace is still usable when offline support is unavailable.
      });
    }
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') { setModal(''); setMenu(''); }
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault(); setModal('search');
      }
    };
    window.addEventListener('keydown',onKey);
    return () => window.removeEventListener('keydown',onKey);
  },[]);
  useEffect(() => { if (ready) localStorage.setItem('baiti-records-v1',JSON.stringify(records)); },[records,ready]);
  useEffect(() => {
    if (!toast) return;
    const timeout = setTimeout(() => setToast(''),2800);
    return () => clearTimeout(timeout);
  },[toast]);

  function navigate(name: string) {
    setActive(name); setQuery(''); setFilter(''); setWarehouse(''); setSort(''); setPage(1); setMobile(false); setMenu(''); setModal('');
    history.replaceState(null,'','#'+encodeURIComponent(name));
  }
  const transactions = ['Penjualan','Pembelian','Faktur'].flatMap(section => records[section].map(row => ({...row,section}))).sort((a,b) => b.date.localeCompare(a.date));
  const current = active === 'Laporan' ? transactions : (records[active] || []);
  const filtered = current.filter(row => (!filter || row.status === filter) && (!warehouse || row.detail === warehouse) && [row.id,row.name,row.detail].join(' ').toLowerCase().includes(query.toLowerCase()));
  if (sort === 'stock') filtered.sort((a,b) => a.amount - b.amount);
  if (sort === 'name') filtered.sort((a,b) => a.name.localeCompare(b.name,'id'));
  const shown = filtered.slice((page-1)*7,page*7);
  const searchResults = modules.filter(name => name.toLowerCase().includes(globalQuery.toLowerCase()));
  const globalRecords = globalQuery.trim() ? Object.entries(records).flatMap(([section,rows]) => rows.filter(row => [row.id,row.name].join(' ').toLowerCase().includes(globalQuery.toLowerCase())).map(row => ({row,section}))).slice(0,8) : [];
  const startMonth = period === periods[2] ? 5 : period === periods[1] ? 3 : 0;

  function exportRows(rows: Row[], filename: string) {
    const cell = (value: string | number) => {
      const raw = String(value);
      return '"' + (/^[=+@\-\t\r\n]/.test(raw) ? "'" : '') + raw.replaceAll('"','""') + '"';
    };
    const csv = ['Nomor,Nama,Jenis,Jumlah,Status,Tanggal', ...rows.map(row => [row.id,row.name,row.detail,row.amount,row.status,row.date].map(cell).join(','))].join('\r\n');
    const url = URL.createObjectURL(new Blob(['\ufeff',csv],{type:'text/csv;charset=utf-8'}));
    const link = document.createElement('a');
    link.href = url; link.download = filename + '.csv'; link.click();
    setTimeout(() => URL.revokeObjectURL(url),1000);
    setToast('Laporan CSV diunduh');
  }
  function create(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const name = String(form.get('name')).trim();
    const detail = String(form.get('detail')).trim();
    if (!name || !detail) { setToast('Nama dan keterangan wajib diisi'); return; }
    const row: Row = {id:'DRAFT-'+crypto.randomUUID().slice(0,8).toUpperCase(),name,detail,amount:Number(form.get('amount')),status:'Draft',date:String(form.get('date'))};
    setRecords(previous => ({...previous,[target]:[row,...(previous[target] || [])]}));
    navigate(target);
    setToast('Draft tersimpan di perangkat ini');
  }
  function openCreate(section: string) { setTarget(section); setMenu(''); setModal('create'); }
  function openRow(row: Row, section: string) { setEntry(row); setTarget(section); setModal('entry'); }
  function table(rows: Row[], dashboard = false) {
    return <div className="table-wrap"><table><thead><tr><th>Nomor Dokumen</th><th>{active === 'Inventori' ? 'Produk' : 'Nama'}</th><th>{active === 'Inventori' ? 'Gudang' : 'Jenis'}</th><th>Tanggal</th><th>{units.includes(active) ? 'Jumlah' : 'Nilai'}</th><th>Status</th><th><span className="sr-only">Detail</span></th></tr></thead><tbody>
      {rows.map(row => <tr key={row.id}><td><button className="doc" onClick={() => openRow(row,'section' in row ? String(row.section) : active)}>{row.id}</button></td><td>{row.name}</td><td className="muted">{row.detail}</td><td className="muted">{dateLabel(row.date)}</td><td className="amount">{!dashboard && units.includes(active) ? number(row.amount) : money(row.amount)}</td><td><span className={'status '+(tones[row.status] || 'gray')}><i/>{row.status}</span></td><td><button className="icon ghost" aria-label={'Lihat '+row.id} onClick={() => openRow(row,'section' in row ? String(row.section) : active)}><ChevronRight size={16}/></button></td></tr>)}
      {!rows.length && <tr><td colSpan={7} className="empty">Tidak ada data yang cocok.</td></tr>}
    </tbody></table></div>;
  }

  return <div className={'shell '+(collapsed ? 'collapsed' : '')}>
    {mobile && <button className="mobile-shade" aria-label="Tutup navigasi" onClick={() => setMobile(false)}/>}
    <aside className={'sidebar '+(mobile ? 'mobile-open' : '')}>
      <div className="brand"><img src="/icon.svg" width="40" height="40" alt=""/><div><strong>Baiti Jannati</strong><small>S O L U T I O N</small></div><button className="icon collapse ghost" aria-label={collapsed ? 'Perluas navigasi' : 'Ciutkan navigasi'} onClick={() => setCollapsed(!collapsed)}>{collapsed ? <ChevronRight size={17}/> : <PanelLeftClose size={17}/>}</button></div>
      <nav aria-label="Navigasi utama">{sections.map(section => <div className="nav-section" key={section.label}><div className="nav-heading">{section.label}</div>{section.items.map(name => {
        const Icon = icons[modules.indexOf(name)];
        return <button key={name} title={name} aria-current={active === name ? 'page' : undefined} className={'nav-link '+(active === name ? 'active' : '')} onClick={() => navigate(name)}><Icon size={17}/><span>{name}</span>{name === 'Persetujuan' && <b className="nav-count">1</b>}</button>;
      })}</div>)}</nav>
      <div className="sidebar-end"><button className="nav-link" onClick={() => setModal('help')} title="Bantuan"><CircleHelp size={17}/><span>Bantuan & panduan</span></button></div>
    </aside>

    <div className="workspace">
      <header className="topbar">
        <div className="crumb"><button className="icon ghost mobile-trigger" aria-label="Buka navigasi" onClick={() => setMobile(true)}><Menu size={21}/></button><Building2 size={17}/><span>Ruang Kerja</span><ChevronRight size={14}/><strong>{active}</strong></div>
        <div className="top-actions">
          <button className="search-trigger" onClick={() => setModal('search')}><Search size={16}/><span>Cari apa saja...</span><kbd>Ctrl K</kbd></button>
          <div className="relative"><button className="icon bell" aria-label="Notifikasi" aria-expanded={menu === 'alerts'} onClick={() => setMenu(menu === 'alerts' ? '' : 'alerts')}><Bell size={19}/>{!read && <i/>}</button>
          {menu === 'alerts' && <div className="popover alerts"><div className="popover-title">Notifikasi <button onClick={() => setRead(true)} className="text-button">Tandai dibaca</button></div>{alerts.map((alert,i) => <button className="alert-item" key={alert} onClick={() => {setRead(true);navigate(['Inventori','Persetujuan','Faktur'][i]);}}><span className="alert-dot"/>{alert}<ChevronRight size={15}/></button>)}</div>}</div>
          <div className="relative profile-wrap"><button className="profile" aria-expanded={menu === 'profile'} onClick={() => setMenu(menu === 'profile' ? '' : 'profile')}><span className="avatar">DA</span><span className="profile-text"><strong>Diana</strong><small>Owner</small></span><ChevronDown size={14}/></button>
          {menu === 'profile' && <div className="popover"><button onClick={() => navigate('Pengaturan')}><Settings size={16}/> Pengaturan</button><button onClick={() => {setMenu('');setModal('help');}}><CircleHelp size={16}/> Bantuan</button></div>}</div>
        </div>
      </header>

      <main>
        {active === 'Dashboard' ? <>
          <div className="page-head"><div><div className="eyebrow"><span/> RINGKASAN BISNIS</div><h1>Dashboard</h1><p>Pantau penjualan, stok, dan keuangan dalam satu tempat.</p></div><button className="button primary" onClick={() => openCreate('Penjualan')}><Plus size={17}/> Buat Transaksi</button></div>
          <section className="hero"><div className="hero-copy"><span className="hero-label"><Sparkles size={14}/> RUANG KERJA OPERASIONAL</span><h2>Selamat datang, Diana!</h2><p>Berikut ringkasan aktivitas bisnis {company}.</p></div><div className="hero-date"><CalendarDays size={17}/> Jumat, 20 November 2026</div><div className="hero-art" aria-hidden="true"><i/><i/><i/><b/><em/></div></section>
          <div className="section-head"><h2>Ringkasan Kinerja</h2><div className="inline-actions"><label className="select-button"><CalendarDays size={15}/><select aria-label="Periode ringkasan" value={period} onChange={event => setPeriod(event.target.value)}>{periods.map(value => <option key={value}>{value}</option>)}</select><ChevronDown size={14}/></label><button className="button secondary compact" onClick={() => exportRows(transactions,'ringkasan-baiti-jannati')}><ArrowDownToLine size={16}/> Ekspor</button></div></div>

          <div className="metrics">{kpis.map((item,i) => <article className={'metric '+item.color} key={item.title}><div className="metric-top"><span className="metric-icon"><item.icon size={19}/></span><button className="icon metric-link" aria-label={'Buka '+item.page} onClick={() => navigate(item.page)}><ArrowUpRight size={17}/></button></div><div className="metric-title">{item.title}</div><div className="metric-value">{item.value}</div><div className="metric-bottom"><span className={'change '+(i === 3 ? 'down' : '')}>{i === 3 ? <ArrowDownRight size={13}/> : <ArrowUpRight size={13}/>} {item.change}</span><span>vs. bulan lalu</span></div></article>)}</div>

          <div className="analytics">
            <section className="card chart-card"><div className="card-head"><div><h2>Tren Pendapatan</h2><p>Pendapatan dan biaya operasional</p></div><div className="legend"><span><i/> Pendapatan</span><span><i/> Biaya</span></div></div>
              <div className="chart"><div className="axis">{['300 jt','225 jt','150 jt','75 jt','0'].map(n => <span key={n}>{n}</span>)}</div><div className="plot"><div className="grid-lines"><i/><i/><i/><i/><i/></div><div className="groups">{months.slice(startMonth).map((month,i) => {
                const idx = i+startMonth;
                return <div className="group" key={month}><button className="bar-pair" aria-label={month+' pendapatan '+revenues[idx]+' juta, biaya '+costs[idx]+' juta'} onMouseEnter={() => setHover(idx)} onMouseLeave={() => setHover(null)} onFocus={() => setHover(idx)} onBlur={() => setHover(null)} onClick={() => setHover(hover === idx ? null : idx)}><i style={{height:revenues[idx]/3+'%'}}/><i style={{height:costs[idx]/3+'%'}}/>{hover === idx && <span className="chart-tip" style={{bottom:revenues[idx]/3+'%'}}>Rp {number(revenues[idx])} jt</span>}</button><span className="month">{month}</span></div>;
              })}</div></div></div>
            </section>
            <section className="card stock-card"><div className="card-head"><div><h2>Status Inventori</h2><p>Distribusi stok per SKU</p></div><button className="icon metric-link" aria-label="Buka inventori" onClick={() => navigate('Inventori')}><ArrowUpRight size={17}/></button></div>
              <div className="stock-body"><div className="donut"><div><strong>326</strong><span>Total SKU</span></div></div><div className="stock-legend">{[['Tersedia','274'],['Stok rendah','38'],['Habis','14']].map(([label,value],i) => <button key={label} onClick={() => {navigate('Inventori');setFilter(label);}}><i className={'dot stock-'+i}/><span>{label}</span><b>{value}</b></button>)}</div></div>
            </section>
          </div>
          <section className="card transactions"><div className="card-head"><div><h2>Transaksi Terbaru</h2><p>Aktivitas penjualan, pembelian, dan faktur</p></div><button className="text-button" onClick={() => navigate('Laporan')}>Lihat semua <ArrowRight size={16}/></button></div>{table(transactions.slice(0,5),true)}</section>
        </> : <>
          <div className="page-head module-head"><div><div className="eyebrow"><span/> {sections.find(section => section.items.includes(active))?.label.toUpperCase()}</div><h1>{active}</h1><p>{descriptions[active]}</p></div>{addable.includes(active) && <button className="button primary" onClick={() => openCreate(active)}><Plus size={17}/> Buat Draft</button>}</div>
          {active === 'Pengaturan' ? <section className="card special"><h2>Profil perusahaan</h2><form onSubmit={event => {event.preventDefault(); const value = String(new FormData(event.currentTarget).get('company')).trim(); if (value) {setCompany(value);localStorage.setItem('baiti-company',value);setToast('Pengaturan tersimpan');}}}><label>Nama perusahaan<input name="company" defaultValue={company} required/></label><button className="button primary">Simpan</button></form></section> :
          active === 'AI Assistant' ? <section className="card special"><div className="eyebrow"><Sparkles size={16}/> SARAN BERBASIS ATURAN</div><h2>Stok yang perlu ditinjau</h2><p>Periksa SKU yang habis atau mencapai batas stok rendah sebelum membuat draft pembelian.</p>{table(records.Inventori.filter(row => ['Habis','Stok rendah'].includes(row.status)))}<button className="button primary" onClick={() => openCreate('Pembelian')}><Plus size={17}/> Draft Pembelian</button></section> :
          <section className="card module-table"><div className="table-tools"><label className="table-search"><Search size={17}/><input aria-label={'Cari '+active} placeholder="Cari nama atau nomor..." value={query} onChange={event => {setQuery(event.target.value);setPage(1);}}/></label><select className="button secondary" aria-label="Filter status" value={filter} onChange={event => {setFilter(event.target.value);setPage(1);}}><option value="">Semua status</option>{[...new Set(current.map(row => row.status))].map(status => <option key={status}>{status}</option>)}</select>{active === 'Inventori' && <><select className="button secondary" aria-label="Filter gudang" value={warehouse} onChange={event => {setWarehouse(event.target.value);setPage(1);}}><option value="">Semua gudang</option>{[...new Set(current.map(row => row.detail))].map(location => <option key={location}>{location}</option>)}</select><select className="button secondary" aria-label="Urutkan inventori" value={sort} onChange={event => {setSort(event.target.value);setPage(1);}}><option value="">Urutkan</option><option value="stock">Stok terendah</option><option value="name">Nama A–Z</option></select></>}<button className="button secondary" onClick={() => exportRows(filtered,active.toLowerCase())}><ArrowDownToLine size={16}/> Ekspor</button></div>{table(shown)}<div className="pagination"><span>{filtered.length} data</span><div><button className="icon" disabled={page === 1} aria-label="Halaman sebelumnya" onClick={() => setPage(page-1)}><ChevronLeft size={17}/></button><span>Halaman {page}</span><button className="icon" disabled={page*7 >= filtered.length} aria-label="Halaman berikutnya" onClick={() => setPage(page+1)}><ChevronRight size={17}/></button></div></div></section>}
        </>}
        <footer>© 2026 {company}<span>Ruang kerja demo</span></footer>
      </main>
    </div>

    <nav className="bottom-nav" aria-label="Navigasi cepat">{['Dashboard','CRM','Inventori','Faktur'].map(name => { const Icon=icons[modules.indexOf(name)];return <button key={name} className={active === name ? 'selected' : ''} onClick={() => navigate(name)}><Icon size={19}/>{name}</button>; })}<button onClick={() => setMobile(true)}><Menu size={19}/>Lainnya</button></nav>
    {modal && <div className="overlay" onClick={() => setModal('')}><section className="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title" onClick={event => event.stopPropagation()}><div className="dialog-head"><h2 id="dialog-title">{({search:'Pencarian Global',create:'Buat Draft',entry:'Detail Dokumen',help:'Bantuan & Panduan'})[modal]}</h2><button className="icon ghost" onClick={() => setModal('')} aria-label="Tutup"><X size={20}/></button></div>
      {modal === 'search' && <><label className="table-search"><Search size={17}/><input autoFocus aria-label="Cari modul atau dokumen" placeholder="Cari modul atau dokumen..." value={globalQuery} onChange={event => setGlobalQuery(event.target.value)}/></label><div className="search-results">{searchResults.map(name => <button key={name} onClick={() => navigate(name)}>{name}<ArrowRight size={16}/></button>)}{globalRecords.map(({row,section}) => <button key={section+row.id} onClick={() => openRow(row,section)}>{row.name} <small>{row.id} · {section}</small></button>)}{!searchResults.length && !globalRecords.length && <p>Hasil tidak ditemukan.</p>}</div></>}
      {modal === 'create' && <form onSubmit={create}><label>Modul<select value={target} onChange={event => setTarget(event.target.value)}>{addable.map(name => <option key={name}>{name}</option>)}</select></label><label>Nama<input name="name" autoFocus required maxLength={100} placeholder="Contoh: PT Natura Kosmetika"/></label><label>Keterangan<input name="detail" required maxLength={120} placeholder="Contoh: Penawaran"/></label><div className="form-grid"><label>{units.includes(target) ? 'Jumlah' : 'Nilai (Rp)'}<input name="amount" type="number" min="0" max="999999999999" step="1" defaultValue="0" required/></label><label>Tanggal<input name="date" type="date" defaultValue="2026-11-20" required/></label></div><div className="dialog-actions"><button type="button" className="button secondary" onClick={() => setModal('')}>Batal</button><button className="button primary">Simpan Draft</button></div></form>}
      {modal === 'entry' && entry && <><dl><dt>Nomor</dt><dd>{entry.id}</dd><dt>Nama</dt><dd>{entry.name}</dd><dt>Keterangan</dt><dd>{entry.detail}</dd><dt>Tanggal</dt><dd>{dateLabel(entry.date)}</dd><dt>{units.includes(target) ? 'Jumlah' : 'Nilai'}</dt><dd>{units.includes(target) ? number(entry.amount) : money(entry.amount)}</dd><dt>Status</dt><dd><span className={'status '+(tones[entry.status] || 'gray')}><i/>{entry.status}</span></dd></dl><div className="dialog-actions"><button className="button secondary" onClick={() => navigate(target)}>Buka {target}</button></div></>}
      {modal === 'help' && <><p>Gunakan menu samping untuk berpindah modul. Tekan <kbd>Ctrl K</kbd> untuk mencari dokumen dan modul, atau pilih Ekspor untuk mengunduh data yang tampil.</p><p>Draft demo disimpan di browser ini.</p></>}
    </section></div>}
    {toast && <div className="toast" role="status"><Check size={18}/>{toast}</div>}
  </div>;
}
