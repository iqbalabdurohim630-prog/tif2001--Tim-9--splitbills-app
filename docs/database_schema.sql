# Splitbill – Database Schema & Data Dictionary

Semua tabel dibuat lewat file migrasi bernomor di `server/migrations/`. Uang disimpan sebagai `BIGINT` rupiah (bukan `float`) untuk menghindari galat pembulatan. Persentase memakai `NUMERIC`.

## Diagram Relasi (ERD ringkas)

```
users ──< bills ──< participants
              └──< bill_items ──< item_assignments >── participants
```

---

## Tabel: `users`

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | `UUID` | PK, default `gen_random_uuid()` | Identifier unik |
| `name` | `VARCHAR(100)` | NOT NULL | Nama tampil |
| `email` | `VARCHAR(150)` | UNIQUE, NOT NULL | Email login (case-insensitive disimpan lower) |
| `password` | `VARCHAR(255)` | NOT NULL | Hash bcrypt, **jangan dikembalikan ke klien** |
| `role` | `VARCHAR(20)` | NOT NULL, default `'user'` | Nilai: `user` |
| `created_at` | `TIMESTAMP` | NOT NULL, default `CURRENT_TIMESTAMP` | Waktu registrasi |

---

## Tabel: `bills`

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | `UUID` | PK | |
| `owner_id` | `UUID` | FK → `users(id)` ON DELETE CASCADE | Pembuat tagihan |
| `title` | `VARCHAR(120)` | NOT NULL | Nama tagihan |
| `venue_name` | `VARCHAR(120)` | | Nama kafe/tempat |
| `bill_date` | `DATE` | NOT NULL, default `CURRENT_DATE` | Tanggal struk |
| `tax_mode` | `VARCHAR(10)` | CHECK `percent` / `nominal` | Mode pajak |
| `tax_value` | `NUMERIC(12,2)` | >= 0, default `10` | Nilai pajak (persen atau nominal Rp) |
| `service_mode` | `VARCHAR(10)` | CHECK `percent` / `nominal` | Mode service charge |
| `service_value` | `NUMERIC(12,2)` | >= 0, default `0` | Nilai service charge |
| `service_split` | `VARCHAR(15)` | CHECK `proportional` / `equal` | Cara bagi service charge |
| `status` | `VARCHAR(12)` | CHECK `draft` / `finalized` | Status tagihan |
| `receipt_url` | `TEXT` | | URL publik foto struk di Supabase Storage |
| `share_code` | `VARCHAR(12)` | UNIQUE | Kode link baca-publik |
| `created_at` | `TIMESTAMP` | NOT NULL | |
| `updated_at` | `TIMESTAMP` | NOT NULL | Diperbarui tiap PUT |

Index: `idx_bills_owner_created` pada `(owner_id, created_at DESC)` untuk daftar tagihan.

---

## Tabel: `participants`

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | `UUID` | PK | |
| `bill_id` | `UUID` | FK → `bills(id)` ON DELETE CASCADE | |
| `name` | `VARCHAR(80)` | NOT NULL | Nama peserta (tidak harus user terdaftar) |
| `sort_order` | `INT` | NOT NULL, default `0` | Urutan menentukan siapa dapat sisa 1 Rp dari pembulatan |

Unique constraint: `(bill_id, name)` – nama tidak boleh kembar dalam satu tagihan.

---

## Tabel: `bill_items`

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | `UUID` | PK | |
| `bill_id` | `UUID` | FK → `bills(id)` ON DELETE CASCADE | |
| `name` | `VARCHAR(100)` | NOT NULL | Nama menu |
| `price` | `BIGINT` | NOT NULL, >= 0 | Harga per unit dalam rupiah (bilangan bulat) |
| `qty` | `INT` | NOT NULL, default `1`, > 0 | Jumlah porsi |

---

## Tabel: `item_assignments`

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `item_id` | `UUID` | FK → `bill_items(id)` ON DELETE CASCADE | |
| `participant_id` | `UUID` | FK → `participants(id)` ON DELETE CASCADE | |

PK komposit: `(item_id, participant_id)`. Menyimpan siapa saja yang menanggung setiap item.

---

## Tabel: `_migrations` (internal)

Dikelola otomatis oleh `scripts/migrate.js`. Menyimpan nama file SQL yang sudah diterapkan agar tidak dijalankan ulang.
