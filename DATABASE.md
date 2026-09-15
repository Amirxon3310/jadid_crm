# Jadid CRM bazasi

Supabase loyihasi yaratildi va `supabase/schema.sql` migratsiyasi qo‘llandi.

## Jadvallar

- `profiles`, `organizations`, `memberships`
- `groups`, `enrollments`, `lessons`, `attendance`
- `assignments`, `assignment_results`

`enrollments` o‘quvchining guruh tarixini saqlaydi. Davomat va vazifa javobi profilga emas, aynan shu a’zolikka bog‘lanadi. Shu sababli o‘quvchi guruh almashtirsa ham eski natijalari yo‘qolmaydi.

## Xavfsizlik

- Barcha public jadvallarda RLS yoqilgan.
- Admin faqat o‘z markazini boshqaradi.
- Ustoz faqat biriktirilgan guruhini boshqaradi.
- O‘quvchi faqat o‘z ma’lumotini ko‘radi va o‘z vazifasiga javob beradi.
- Rol foydalanuvchi yuborgan metadata’dan olinmaydi.
- Birinchi akkaunt admin, keyingilari o‘quvchi bo‘ladi.
- Secret/service-role kaliti mijoz kodida ishlatilmaydi.

Supabase Security Advisor yakuniy tekshiruvda muammo topmadi. Performance Advisor’dagi `unused_index` xabarlari baza hali bo‘sh bo‘lgani uchun kutilgan holat; ma’lumot va real trafik paydo bo‘lgach qayta tekshiriladi.
