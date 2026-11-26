# Splitbill – Algoritma Pembagian Tagihan & Pajak

Dokumen ini menjelaskan aturan kalkulasi `server/src/utils/splitCalculator.js`.

## Aturan Pembagian

| Komponen | Cara Bagi | Alasan |
|---|---|---|
| Item makanan/minuman | Ke penanggung item saja, dibagi rata (largest-remainder) | Adil sesuai konsumsi |
| **Pajak (tax)** | **Dibagi rata ke SEMUA peserta** | Inti aplikasi – pajak tidak ditanggung satu orang |
| Service charge | Proporsional thd subtotal (default) atau rata | Fleksibel kafe berbeda |
| Sisa pembulatan 1 Rp | Ke peserta urutan `sort_order` terkecil (terdepan) | Total semua = total struk |

## Langkah Kalkulasi

1. **Item → subtotal per orang**
   `harga × qty` lalu dibagi rata antar `assigneeIds` dengan `splitEvenly`.

2. **Pajak total**
   - Mode `percent`: `Math.round(subtotalAll × taxValue / 100)`
   - Mode `nominal`: pakai nilai langsung (angka dari struk)

3. **Bagikan pajak ke SEMUA peserta** – rata via `splitEvenly(taxTotal, N)`.
   Sisa `taxTotal mod N` rupiah diberikan ke peserta urutan `sort_order` pertama.

4. **Service charge** (opsional)
   - Mode `percent`: `Math.round(subtotalAll × serviceValue / 100)`
   - `serviceSplit = 'equal'` → `splitEvenly`
   - `serviceSplit = 'proportional'` → `splitProportionally` (bobot = subtotal per orang)

5. **Total per orang** = `subtotal + pajak + service`

6. **Invarian wajib**: `Σ total[i]` = `subtotalAll + taxTotal + serviceTotal` = `grandTotal`

## Contoh TC1 (dari PDF panduan)

> Andi pesan Rp 40.000, Budi Rp 25.000, Cici Rp 15.000. Pajak 10%.

| Orang | Subtotal | Pajak (rata) | Service | **Total** |
|---|---|---|---|---|
| Andi | 40.000 | 2.667 | 0 | **42.667** |
| Budi | 25.000 | 2.667 | 0 | **27.667** |
| Cici | 15.000 | 2.666 | 0 | **17.666** |
| **Total** | **80.000** | **8.000** | **0** | **88.000** |

Pembulatan pajak: `8000 / 3 = 2666.67` → base = 2666, remainder = 2 → 2 orang pertama dapat +1.

## Fungsi Helper

```js
splitEvenly(total, n)
// → array panjang n, jumlah selalu = total (largest-remainder)

splitProportionally(total, weights)
// → array proporsional thd bobot, jumlah selalu = total
```

Test: `server/tests/unit/splitCalculator.test.js` mencakup TC1 + edge cases.
