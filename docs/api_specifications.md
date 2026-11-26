# Splitbill API Specifications

Dokumen kontrak REST API resmi proyek **Splitbill** (Stack: Node.js Express + PostgreSQL).
Seluruh tim (Frontend & Backend) menggunakan spesifikasi ini sebagai acuan integrasi.

> [!IMPORTANT]
> **Base URL:** `http://localhost:5000/api/v1`
> Semua nominal uang adalah **bilangan bulat rupiah** (integer, bukan desimal).
> Perubahan kontrak ini wajib membuat PR berlabel `contract-change` yang disetujui FE dan BE.

---

## 1. Informasi Umum

| Item | Nilai |
|---|---|
| Base URL (dev) | `http://localhost:5000/api/v1` |
| Content-Type | `application/json` |
| Auth Header | `Authorization: Bearer <token>` |
| Token | JWT, valid 24 jam |

### Format Respons Sukses
```json
{
  "success": true,
  "message": "Pesan deskriptif",
  "data": {},
  "meta": {}
}
```

### Format Respons Error
```json
{
  "success": false,
  "message": "Ringkasan error",
  "errors": [
    { "field": "email", "message": "Format email tidak valid" }
  ]
}
```

### Kode Status HTTP

| Status | Arti |
|---|---|
| `200` | OK – request berhasil |
| `201` | Created – resource baru dibuat |
| `400` | Bad Request – validasi gagal |
| `401` | Unauthorized – token tidak ada / tidak valid / kedaluwarsa |
| `403` | Forbidden – bukan pemilik resource |
| `404` | Not Found – resource tidak ada |
| `409` | Conflict – duplikat (email sudah terdaftar, nama peserta kembar) |
| `422` | Unprocessable Entity – aturan bisnis dilanggar (item tanpa penanggung, belum ada peserta) |
| `500` | Internal Server Error |

---

## 2. Health Check

### `GET /health`

| | |
|---|---|
| **Auth** | Tidak diperlukan |
| **Response `200`** | `{ success, message, data: { status, timestamp } }` |

---

## 3. Auth Endpoints (`/auth`)

### `POST /auth/register`
Daftarkan akun baru.

- **Auth:** Tidak
- **Body:**
```json
{ "name": "Andi", "email": "andi@example.com", "password": "Password123!" }
```
- **Validasi:** `name` 2-100 kar; `email` valid & unik; `password` min 8 kar.
- **`201`:**
```json
{
  "success": true, "message": "User registered successfully",
  "data": {
    "user": { "id": "uuid", "name": "Andi", "email": "andi@example.com",
              "role": "user", "created_at": "2026-11-26T..." },
    "token": "eyJ..."
  }
}
```
- **Error:** `400` validasi, `409` email sudah terdaftar.

---

### `POST /auth/login`
Login dan dapatkan JWT (maks 10 percobaan / 15 menit per IP).

- **Auth:** Tidak
- **Body:** `{ "email": "andi@example.com", "password": "Password123!" }`
- **`200`:** sama seperti register, field `data.user` tanpa `password`.
- **Error:** `400` body kosong, `401` email/password salah (pesan sama untuk keduanya).

---

### `GET /auth/me`
Profil pengguna dari JWT.

- **Auth:** Bearer token (wajib)
- **`200`:** `{ data: { user: { id, name, email, role, created_at } } }`
- **Error:** `401`

---

## 4. Bills Endpoints (`/bills`)

### `GET /bills`
Daftar tagihan milik user, dengan pencarian & paginasi.

- **Auth:** Wajib
- **Query:** `?search=kafe&status=draft&page=1&limit=10` (limit maks 50)
- **`200`:**
```json
{
  "success": true, "message": "Bills fetched successfully",
  "data": [{ "id": "uuid", "title": "Makan Siang", "venue_name": "Kafe ABC",
              "bill_date": "2026-11-26", "status": "draft", "created_at": "..." }],
  "meta": { "totalRows": 42, "totalPages": 5, "currentPage": 1 }
}
```
- **Error:** `401`

---

### `POST /bills`
Buat tagihan baru.

- **Auth:** Wajib
- **Body:**
```json
{
  "title": "Makan Siang Kafe ABC",
  "venueName": "Kafe ABC",
  "billDate": "2026-11-26",
  "taxMode": "percent",
  "taxValue": 10,
  "serviceMode": "percent",
  "serviceValue": 0,
  "serviceSplit": "proportional"
}
```
- **Validasi:** `taxMode` ∈ `{percent,nominal}`, `serviceMode` ∈ `{percent,nominal}`, `serviceSplit` ∈ `{proportional,equal}`.
- **`201`:** detail tagihan baru.
- **Error:** `400`, `401`

---

### `GET /bills/:id`
Detail tagihan + participants + items (dengan assigneeIds).

- **Auth:** Wajib (harus pemilik)
- **`200`:** `{ data: { ...bill, participants: [...], items: [...] } }`
- **Error:** `401`, `403`, `404`

---

### `PUT /bills/:id`
Update field tagihan (partial update diizinkan).

- **Auth:** Wajib (harus pemilik)
- **Body:** field opsional (sama seperti POST)
- **`200`:** tagihan yang diperbarui
- **Error:** `400`, `401`, `403`, `404`

---

### `DELETE /bills/:id`
Hapus tagihan beserta semua peserta, item, dan asignment (cascade).

- **Auth:** Wajib (harus pemilik)
- **`200`:** `{ success: true, message: "Bill deleted successfully", data: null }`
- **Error:** `401`, `403`, `404`

---

### `POST /bills/:id/receipt`
Upload foto struk (multipart/form-data, field `receipt`).

- **Auth:** Wajib (harus pemilik)
- **Validasi:** JPEG/PNG/WEBP, maks 2 MB.
- **`200`:** `{ data: { receiptUrl: "https://..." } }`
- **Error:** `400` tipe/ukuran salah, `403`, `404`

---

## 5. Participants Endpoints

### `POST /bills/:billId/participants`
Tambah peserta ke tagihan.

- **Auth:** Wajib (harus pemilik tagihan)
- **Body:** `{ "name": "Budi" }`
- **`201`:** `{ data: { id, bill_id, name, sort_order } }`
- **Error:** `400`, `409` nama kembar, `403`, `404`

---

### `PATCH /participants/:id`
Ubah nama peserta.

- **Auth:** Wajib
- **Body:** `{ "name": "Budi Santoso" }`
- **`200`:** peserta yang diperbarui
- **Error:** `400`, `403`, `404`, `422` tagihan sudah finalized

---

### `DELETE /participants/:id`
Hapus peserta (cascade hapus asignment).

- **Auth:** Wajib
- **`200`:** `{ data: null }`
- **Error:** `403`, `404`, `422` tagihan sudah finalized

---

## 6. Items Endpoints

### `POST /bills/:billId/items`
Tambah item menu beserta penanggung.

- **Auth:** Wajib (harus pemilik tagihan)
- **Body:**
```json
{
  "name": "Nasi Goreng",
  "price": 25000,
  "qty": 1,
  "assigneeIds": ["participant-uuid-1", "participant-uuid-2"]
}
```
- **Validasi:** `price` >= 0 (integer), `qty` > 0, `assigneeIds` tidak boleh kosong dan harus anggota tagihan ini.
- **`201`:** `{ data: { id, bill_id, name, price, qty, assigneeIds } }`
- **Error:** `400`, `422` assigneeIds kosong/tidak valid, `403`, `404`

---

### `PUT /items/:id`
Update item (partial update).

- **Auth:** Wajib
- **Body:** field opsional sama seperti POST
- **`200`:** item yang diperbarui
- **Error:** `400`, `403`, `404`, `422` tagihan sudah finalized

---

### `DELETE /items/:id`
Hapus item.

- **Auth:** Wajib
- **`200`:** `{ data: null }`
- **Error:** `403`, `404`, `422` tagihan sudah finalized

---

## 7. Summary & Finalize

### `GET /bills/:id/summary`
Hitung pembagian tagihan per orang (sumber kebenaran angka – FE tidak menghitung ulang).

- **Auth:** Wajib
- **`200`:**
```json
{
  "success": true,
  "data": {
    "subtotal": 80000,
    "taxTotal": 8000,
    "serviceTotal": 0,
    "grandTotal": 88000,
    "taxRule": "equal",
    "perPerson": [
      { "participantId": "p1", "name": "Andi", "subtotal": 40000, "tax": 2667, "service": 0, "total": 42667 },
      { "participantId": "p2", "name": "Budi", "subtotal": 25000, "tax": 2667, "service": 0, "total": 27667 },
      { "participantId": "p3", "name": "Cici", "subtotal": 15000, "tax": 2666, "service": 0, "total": 17666 }
    ]
  }
}
```
- **Error:** `401`, `403`, `404`, `422` belum ada peserta

---

### `POST /bills/:id/finalize`
Kunci tagihan dan buat `shareCode`.

- **Auth:** Wajib (harus pemilik)
- **`200`:** `{ data: { shareCode: "AbCdEf123456" } }`
- **Error:** `401`, `403`, `404`, `422` tagihan tidak valid untuk dikunci

---

## 8. Public Endpoint

### `GET /public/bills/:shareCode`
Tampilan read-only untuk dibagikan (tanpa email pemilik).

- **Auth:** Tidak diperlukan
- **`200`:** detail tagihan + summary (tanpa data sensitif)
- **Error:** `404`

---

## 9. Dashboard

### `GET /dashboard/stats`
Agregasi statistik tagihan milik user.

- **Auth:** Wajib
- **`200`:**
```json
{
  "success": true,
  "data": {
    "totalBills": 12,
    "totalSpending": 2500000,
    "totalTaxSplit": 250000,
    "recent": [
      { "id": "uuid", "title": "Makan Siang", "grandTotal": 88000, "created_at": "..." }
    ]
  }
}
```
- **Error:** `401`
