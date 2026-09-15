# Jadid CRM 0.3

Flutter Web + Supabase asosidagi o‘quv markaz CRM. Admin, ustoz va o‘quvchi uchun haqiqiy login va server darajasidagi ruxsatlar mavjud.

## Ishga tushirish

Dart 3.9 yoki yangiroq SDK kerak. Loyiha Flutter 3.41.2 / Dart 3.11.0 bilan
tekshirilgan. VS Code uchun `.vscode/settings.json` ichidagi `dart.flutterSdkPath`
shu kompyuterdagi `/Users/macstore.uz/development/flutter` papkasiga yo‘naltirilgan.
Boshqa kompyuterda bu yo‘lni o‘zingizdagi Flutter SDK manziliga almashtiring.
SDK sozlamasi yangilangandan keyin VS Code’da `Developer: Reload Window` bajaring.

```bash
flutter pub get
flutter run -d chrome
```

Tekshirish:

```bash
dart format lib test
flutter analyze
flutter test
```

Supabase manzili va publishable key `lib/core/app_config.dart` ichida. Bu kalit brauzer uchun xavfsiz; secret yoki service-role kalitini hech qachon Flutter kodiga qo‘ymang. Istalsa qiymatlar build vaqtida beriladi:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

## Login bilan kirish

Yangi akkaunt uchun ism, login, parol va `O‘quvchi` yoki `Ustoz` roli tanlanadi.
Login 3–32 ta lotin harfi, raqam yoki `_` belgisidan iborat; katta-kichik harf
farqlanmaydi. Email yoki Gmail akkaunti kerak emas.

Supabase Auth ichida login `LOGIN@login.jadid.invalid` texnik identifikatoriga
aylantiriladi. Bu manzilga xat yuborilmaydi. **Authentication → Sign In / Providers
→ Email → Confirm email** o‘chirilgan bo‘lishi shart. Texnik domenni keyin o‘zgartirmang:
u akkaunt identifikatorining bir qismidir. Email orqali parol tiklash bu akkauntlar
uchun ishlamaydi; parol tiklash administrator orqali amalga oshirilishi kerak.

Mavjud bazaga `supabase/username_registration.sql` qo‘llanadi. Bu patch yangi
akkauntning tanlangan rolini `memberships`ga saqlaydi; metadata keyinchalik
almashtirilsa ham rol o‘zgarmaydi. `admin` sifatida ochiq ro‘yxatdan o‘tish yo‘q.
Mavjud admin va boshqa akkauntlar o‘z rolini saqlaydi va eski email/parol bilan
kirishi mumkin. Yangi bazada birinchi adminni ishonchli administrator bazada
alohida tayinlashi kerak. Ustozga guruhni admin biriktiradi.

## Ishlaydigan oqimlar

- Admin: foydalanuvchilar, rollar, guruhlar va biriktirishlar.
- Ustoz: o‘z guruhlari, dars qo‘shish, davomat, vazifa berish va tekshirish.
- O‘quvchi: o‘z guruhi, davomat, vazifa va javob yuborish.
- Guruh ichida: ma’lumot, davomat, uy vazifalari, jurnal va reyting.
- Ma’lumotlar Supabase PostgreSQL’da saqlanadi; sahifa yangilanganda yo‘qolmaydi.

## Kod tuzilishi

```text
lib/
  core/       nom, rang va yordamchi funksiyalar
  data/       modellar va barcha Supabase amallari
  features/   login, dashboard, guruhlar, odamlar va vazifalar UI’i
supabase/
  schema.sql  to‘liq baza va RLS qoidalari
```

Asosiy qoida: UI bazaga to‘g‘ridan-to‘g‘ri tarqalib ketmagan. Barcha o‘qish/yozish `lib/data/crm_store.dart` ichida, shu sababli kodni keyin o‘zgartirish oson.

## Web build va deploy

```bash
flutter build web --release
```

Tayyor statik sayt `build/web` papkasida paydo bo‘ladi. Cloudflare Pages uchun build command `flutter build web --release`, output directory esa `build/web`.

## Eslatma

Testlar login loading holati, yuqoridagi bildirishnomalar, server xatolari, profil ruxsatlari, statistika formulasi hamda menyu animatsiyasining oraliq kadrlarini qamraydi.
`supabase/profile_metrics_test.sql` server ruxsatlari va oylik statistika tarixini tranzaksiyada tekshiradi; yakunda barcha sinov yozuvlari `ROLLBACK` qilinadi.

## Guruh bo‘yicha yozish ruxsatlarini yangilash

Yangi baza uchun `supabase/schema.sql` qo‘shimcha guruh tekshiruvlarini o‘z ichiga oladi.
Mavjud baza uchun `supabase/fix_group_write_policies.sql` faylini Supabase SQL Editor’da
bajaring. U davomat va vazifa javobidagi biriktirish aynan dars/vazifa guruhiga tegishli
bo‘lishini talab qiluvchi qo‘shimcha RLS siyosatlarini o‘rnatadi. Patch mavjud
ma’lumotlarni o‘chirmaydi; oldingi noto‘g‘ri guruhga bog‘langan yozuvlarni avtomatik
ko‘chirmaydi. Jonli bazada qo‘llash va SQL tekshiruvlari alohida bajarilishi kerak.


## Profil va dashboard statistikasi

Mavjud bazaga `supabase/profile_metrics.sql` migratsiyasi bir marta qo‘llanadi.
Yangi bazada shu o‘zgarishlar `supabase/schema.sql` ichida mavjud.

Avatar menyusidagi **Mening profilim** orqali shaxsiy ma’lumotlar va rasm tahrirlanadi.
Admin **Foydalanuvchilar** orqali istalgan foydalanuvchini, shuningdek ustoz/o‘quvchi
ro‘yxatidan kerakli profilni ochadi. Ustoz o‘z shaxsiy ma’lumotlarini o‘zgartiradi,
o‘quvchi esa faqat avatarini yangilaydi. Admin va o‘quvchining guruhiga biriktirilgan ustoz **O‘qish holati**ni
belgilaydi: o‘qiyapti, muvaffaqiyatli bitirgan yoki muvaffaqiyatsiz yakunlagan.
Bu ruxsatlar serverdagi `save_profile` orqali ham tekshiriladi.

Profil emaili ixtiyoriy aloqa manzili; loginni o‘zgartirmaydi. Filial admin qo‘shgan
ro‘yxatdan tanlanadi. Avatar JPG/PNG, maksimum 1000 px va 2 MB; `profile-avatars`
yopiq bucketida saqlanadi va vaqtinchalik havola orqali ko‘rsatiladi.

- **Jami xodimlar**: admin va ustozlar.
- **Jami o‘quvchilar**: barcha o‘quvchi akkauntlari, guruhsizlar ham kiradi.
- **Bitirgan o‘quvchilar**: o‘qishni muvaffaqiyatli yoki muvaffaqiyatsiz yakunlaganlar.
- **Muvaffaqiyatli bitirganlar foizi**: muvaffaqiyatli bitirganlar / jami o‘quvchilar × 100.
- Oylik o‘zgarish: (hozirgi qiymat − bir oy oldingi qiymat) / bir oy oldingi qiymat × 100.

O‘sish yashil, kamayish qizil, o‘zgarishsiz qiymat neytral ko‘rsatiladi. Oldingi
qiymat 0, hozirgi qiymat musbat bo‘lsa matematik foiz aniqlanmaydi va **Yangi**
yoziladi. Ikkalasi 0 bo‘lsa **0%**, taqqoslash tarixi bo‘lmasa **—** ko‘rsatiladi.
Tarix migratsiya paytidan yig‘iladi; undan oldingi ma’lumotlar to‘qib chiqarilmaydi.
Markaz bir oydan kam avval yaratilgan bo‘lsa, oldingi ko‘rsatkichlar 0 deb olinadi.


## Saqlashdan keyingi yangilanish

Guruh, dars, vazifa, davomat va profil o‘zgarishlari server javobini kutmasdan
lokal holatda ko‘rinadi. So‘rovlar fonda ketma-ket yuboriladi. Xatoda rad etilgan
amal bekor qilinadi, keyingi mustaqil o‘zgarishlar saqlanadi. Yangi guruhga darhol
qo‘shilgan dars va vazifalarning vaqtinchalik IDlari server IDlariga almashtiriladi;
guruh saqlanmasa unga bog‘liq yangi yozuvlar ham olib tashlanadi.

Profil maydonlarini saqlash vaqtida ham tahrirlash mumkin. Xatoda keyinroq
kiritilgan, hali saqlanmagan matn o‘chmaydi. Joriy statistika lokal foydalanuvchilar
asosida darhol qayta hisoblanadi; bir oy oldingi taqqoslash qiymatlari saqlanadi.
Login va ro‘yxatdan o‘tishda esa server tekshiruvi tugaguncha tugmada loading turadi.

Barcha jadvallarni o‘qish akkauntga dastlab kirishda bajariladi. Token yangilanishi
va takroriy kirish hodisalari mavjud store va ochiq sahifani almashtirmaydi.
“Yangilash” menyusi yo‘q; odatiy saqlash amallari to‘liq qayta yuklashni chaqirmaydi.

## Ustoz kabineti va guruh boshqaruvi

Admin **Guruhlar**da yangi guruh ochadi; ustozni darhol yoki keyinroq biriktiradi
(“Hozircha biriktirilmagan” holati ham bo‘lishi mumkin). Guruh uchun holat — **Faol**,
**Tugatilgan** yoki **Muzlatilgan** — va haftalik dars kunlari belgilanadi.

Ustoz dashboardida faqat o‘ziga biriktirilgan guruhlar bo‘yicha statistika chiqadi:
jami guruhlar, jami o‘quvchilar, ketgan o‘quvchilar va bitirgan o‘quvchilar foizi
(bitirganlar / jami o‘quvchilar × 100). Har bir guruh kartasida holati, davomat,
uy vazifa bajarilishi va o‘quvchilar reytingi ko‘rinadi. **Faqat admin**
o‘quvchini **Aktiv / Ketgan / Tugatgan** deb belgilaydi (tugma qatori orqali,
dropdown emas); guruhning o‘z ustozi bu holatni o‘zgartira olmaydi, faqat
ko‘radi. Bu holat guruh faol bo‘lishidan qat’i nazar o‘quvchining shu guruhdagi
tarixida saqlanadi. Cheklov serverda `set_enrollment_status` orqali ham
tekshiriladi.

Guruhda haftalik dars kunlaridan tashqari kunlik dars vaqti (boshlanish/tugash)
ham belgilanadi. **Davomat** bo‘limida alohida jadval yo‘q: shu kun va shu vaqt
oralig‘ida ustoz avval o‘zini kamerada suratga oladi (brauzerda `getUserMedia`,
mobil/ilovada qurilma kamerasi orqali), so‘ng bugungi dars nomini kiritib
darsni boshlaydi va o‘quvchilarni **Keldi/Kelmadi** svicheri bilan belgilaydi;
kelgan deb belgilansa kelish vaqti darsning boshlanish vaqtiga qarab avtomatik
qo‘yiladi, ustoz xohlasa vaqtni qo‘lda o‘zgartiradi. Dars vaqtidan tashqarida
ustoz davomat qila olmaydi — faqat admin istalgan vaqtda amalga oshiradi. Surat
har dars uchun bitta marta olinadi va faqat shu guruh xodimlariga ko‘rinadi;
sana, vaqt oralig‘i va guruh boshqa bo‘lsa server ham rad etadi. Uy vazifasi
shu darsga bog‘lanadi; o‘quvchi javob yuboradi, ustoz tekshiradi va o‘tilgan
darslarni ko‘rishda davom etadi.

**Qatnashdi** yoki **Kechikdi** deb belgilangan har bir dars uchun o‘quvchiga bir
marta 10 ball beriladi (qayta saqlash ballarni takrorlamaydi). Ushbu o‘zgarishlar
`supabase/migrations/20260914175803_teacher_workspace.sql`,
`supabase/migrations/20260914234429_group_creation_visibility.sql`,
`supabase/migrations/20260915063000_enrollment_status_admin_only.sql`,
`supabase/migrations/20260916070000_attendance_arrival_time.sql`,
`supabase/migrations/20260916090000_lesson_window_and_homework_files.sql` va
`supabase/migrations/20260916140000_score_awards.sql`
orqali mavjud bazaga qo‘llanadi; yangi bazada `schema.sql` ichida allaqachon
mavjud. `supabase/teacher_workspace_test.sql` begona guruhga yozish, selfisiz
yoki boshqa kundagi davomat, va ball takrorlanishini tranzaksiyada tekshiradi.

**Reyting** bo‘limida har bir o‘quvchining ballari to‘rt ustunda ajratilgan:
dars ballari (davomat + qabul qilingan vazifa), qo‘shimcha **rag‘bat** (yashil,
`+`), qo‘shimcha **jarima** (qizil, `−`) va **jami**. Ro‘yxat jami ball bo‘yicha
tartiblanadi. O‘quvchi ustiga bosilsa, unga berilgan barcha qo‘shimcha ballar
tarixi ochiladi: kim berdi, qancha va qanday izoh bilan. Admin va shu guruh
ustozi **Ball qo‘shish** oynasidan yangi ball beradi: son va izoh kiritiladi,
son minus bilan yozilsa (masalan `-5`) jarima bo‘ladi va oyna buni saqlashdan
oldin rangi bilan ko‘rsatadi. O‘quvchi faqat o‘z
tarixini ko‘radi. Cheklovlar `score_awards` jadvalining RLS qoidalarida ham
takrorlangan, jami ball esa serverdagi hisobga ham kiradi.

Reyting o‘yin ko‘rinishida: 1–3 o‘rin toj bilan (oltin, kumush, bronza)
belgilanadi. Ballar faqat ikki rangda: musbat — yashil, manfiy — qizil.
**Jamoa tuzish** tugmasi jadvalda belgilash imkonini
ochadi: bir nechta o‘quvchi tanlansa, ularning ballari qo‘shiladi va shu
jamoa qolgan o‘quvchilar orasida nechanchi o‘rinda bo‘lishi ko‘rsatiladi
(masalan “Abdulloh + Akbar — 145 ball, 2-o‘rinda bo‘lardi”). Bu faqat
taqqoslash uchun: tanlov hech qayerga saqlanmaydi, o‘quvchilarning shaxsiy
ballari o‘zgarmaydi, boshqa juftlikni sinash uchun **Tozalash** bosiladi.

Uy vazifasi bitta “Vazifa” maydoni bilan beriladi (alohida “tushuntirish”
maydoni yo‘q) va ixtiyoriy fayl biriktiriladi (`homework-files` yopiq
bucketida saqlanadi, faqat shu guruh xodimlari va o‘quvchilari ko‘radi).
Muddat sukut bo‘yicha 1 haftadan keyin; ustoz xohlasa sanani o‘zgartiradi.

## O‘quvchi kabineti

- Dashboarddagi ballar — `accepted` holatidagi vazifalar baholari yig‘indisi,
  **Qatnashdi**/**Kechikdi** deb belgilangan har bir dars uchun 10 ball, hamda
  xodim qo‘shgan rag‘bat va jarima ballari. Bir vazifani yoki davomatni qayta
  saqlash ballarni takroran qo‘shmaydi.
- Reyting jami ball bo‘yicha: yuqoriroq ball to‘plaganlar soni + 1. Teng ballar
  bir xil o‘rinni oladi. Guruh reytingi tanlangan guruh a’zolari orasida hisoblanadi.
- Kurs foizi — `completed` darslar / jami darslar. `cancelled` darslar hisobga
  kirmaydi. Dars bo‘lmasa foiz o‘rnida **—** chiqadi. Ustoz yoki admin guruhning
  dars jadvalidagi holat menyusida darsni **O‘tilgan** deb belgilaydi.
- **Guruhlarim**: aktiv va tugatilgan guruhlar. Admin yoki shu guruh ustozi
  guruhdagi o‘quvchilar ro‘yxatida **Aktiv / Tugatgan** holatini o‘zgartiradi.
  Tugatilgan guruh, darslar va eski vazifalar o‘quvchiga ko‘rinishda davom etadi.
- **To‘lovlar**: admin so‘mda to‘lov, sana, usul va ixtiyoriy guruh/izoh kiritadi.
  O‘quvchi faqat o‘z to‘lovlarini ko‘radi. Ustoz to‘lovlarga kira olmaydi.
- Admin **Filiallar** bo‘limida ro‘yxatni to‘ldiradi; profilning **Filial**
  maydoni shu ro‘yxatdan tanlanadi. O‘quvchi shaxsiy ma’lumotlarini tahrirlamaydi,
  faqat avatar yuklashi yoki o‘chirishi mumkin. Cheklovlar serverda ham tekshiriladi.

Mavjud baza uchun migratsiya: `supabase/migrations/20260914125723_student_portal.sql`.
Ulangan loyihaga qo‘llandi. Yangi baza uchun `schema.sql` ushbu o‘zgarishlarni ham
o‘z ichiga oladi. `supabase/student_portal_test.sql` haqiqiy RLS va RPC ruxsatlarini
tranzaksiyada tekshiradi, yakunda sinov yozuvlarini `ROLLBACK` qiladi.
