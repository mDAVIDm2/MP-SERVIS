import type { CatalogSeedRow } from './service-catalog-seed.types';

/**
 * Доп. позиции: мойки, детейлинг, автозвук, стёкла, расширение СТО.
 * Подключается в SERVICE_CATALOG_SEED и миграцию 1732800000000.
 */
export const SERVICE_CATALOG_SEED_EXTRA: CatalogSeedRow[] = [
  // ——— СТО: ТО и обслуживание ———
  { id: 'svc_maint_fuel_filter', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена топливного фильтра', defaultDurationMinutes: 60, sortOrder: 150 },
  { id: 'svc_maint_glow_plugs', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена свечей накаливания (дизель)', defaultDurationMinutes: 90, sortOrder: 160 },
  { id: 'svc_maint_gbo', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Обслуживание и регулировка ГБО', defaultDurationMinutes: 90, sortOrder: 170 },
  { id: 'svc_maint_injector_clean', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Промывка форсунок / впускного тракта', defaultDurationMinutes: 90, sortOrder: 180 },
  { id: 'svc_maint_timing_rollers', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена роликов / натяжителя ремня ГРМ', defaultDurationMinutes: 120, sortOrder: 190, requiredSkill: 'ENGINE' },
  { id: 'svc_maint_ps_fluid', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена жидкости ГУР', defaultDurationMinutes: 60, sortOrder: 200 },
  { id: 'svc_maint_diff_oil', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена масла в редукторе / мосту', defaultDurationMinutes: 45, sortOrder: 210 },
  { id: 'svc_maint_transfer_case', categoryKey: 'maintenance', categoryName: 'ТО и обслуживание', name: 'Замена масла в раздаточной коробке', defaultDurationMinutes: 45, sortOrder: 220 },
  // ——— СТО: двигатель ———
  { id: 'svc_eng_eg_r', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Чистка / замена клапана EGR', defaultDurationMinutes: 120, sortOrder: 80, requiredSkill: 'ENGINE' },
  { id: 'svc_eng_lambda', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Замена датчиков кислорода (лямбда-зонды)', defaultDurationMinutes: 60, sortOrder: 90, requiredSkill: 'ENGINE' },
  { id: 'svc_eng_maf', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Замена / чистка ДМРВ', defaultDurationMinutes: 45, sortOrder: 100 },
  { id: 'svc_eng_catalyst', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Замена катализатора / пламегасителя', defaultDurationMinutes: 120, sortOrder: 110, requiredSkill: 'ENGINE' },
  { id: 'svc_eng_mount', categoryKey: 'engine', categoryName: 'Двигатель', name: 'Замена опор двигателя / КПП', defaultDurationMinutes: 120, sortOrder: 120, requiredSkill: 'ENGINE' },
  // ——— СТО: подвеска ———
  { id: 'svc_susp_silent', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена сайлентблоков (рычаг / подрамник)', defaultDurationMinutes: 180, sortOrder: 100, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_strut_mount', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена опорного подшипника / опоры амортизатора', defaultDurationMinutes: 90, sortOrder: 110, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_tie_rod', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена рулевых тяг / наконечников', defaultDurationMinutes: 90, sortOrder: 120, requiredSkill: 'SUSPENSION' },
  { id: 'svc_susp_subframe', categoryKey: 'suspension', categoryName: 'Подвеска и рулевое', name: 'Замена подушек / крепления подрамника', defaultDurationMinutes: 240, sortOrder: 130, requiredSkill: 'SUSPENSION' },
  // ——— СТО: тормоза ———
  { id: 'svc_brake_hand', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Обслуживание / замена тросов ручного тормоза', defaultDurationMinutes: 90, sortOrder: 70 },
  { id: 'svc_brake_booster', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Диагностика / замена вакуумного усилителя', defaultDurationMinutes: 120, sortOrder: 80 },
  { id: 'svc_brake_master', categoryKey: 'brakes', categoryName: 'Тормозная система', name: 'Замена главного тормозного цилиндра', defaultDurationMinutes: 90, sortOrder: 90 },
  // ——— СТО: электрика ———
  { id: 'svc_el_dvr', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Установка видеорегистратора (скрытый монтаж)', defaultDurationMinutes: 60, sortOrder: 60, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_el_parking_sens', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Установка парктроников', defaultDurationMinutes: 90, sortOrder: 70, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_el_alternator_diag', categoryKey: 'electrical', categoryName: 'Электрика', name: 'Диагностика системы зарядки', defaultDurationMinutes: 45, sortOrder: 80, requiredSkill: 'ELECTRICAL' },
  // ——— СТО: шины ———
  { id: 'svc_tire_rim_straight', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Правка / прокатка литого диска', defaultDurationMinutes: 60, sortOrder: 60, requiredSkill: 'TIRES' },
  { id: 'svc_tire_tpms', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Установка / программирование датчиков TPMS', defaultDurationMinutes: 45, sortOrder: 70, requiredSkill: 'TIRES' },
  { id: 'svc_tire_runflat', categoryKey: 'tires', categoryName: 'Шины и колёса', name: 'Шиномонтаж RunFlat / низкопрофиль (комплект)', defaultDurationMinutes: 90, sortOrder: 80, requiredSkill: 'TIRES' },
  // ——— СТО: кузов (доп.) ———
  { id: 'svc_body_skid', categoryKey: 'body', categoryName: 'Кузов', name: 'Снятие / установка защиты картера', defaultDurationMinutes: 30, sortOrder: 60 },
  { id: 'svc_body_undercoat', categoryKey: 'body', categoryName: 'Кузов', name: 'Антикор / обработка скрытых полостей', defaultDurationMinutes: 120, sortOrder: 70, requiredSkill: 'BODY' },
  { id: 'svc_body_chip', categoryKey: 'body', categoryName: 'Кузов', name: 'Локальный подкрас сколов (точечный ремонт)', defaultDurationMinutes: 90, sortOrder: 80, requiredSkill: 'BODY' },
  // ——— СТО: диагностика ———
  { id: 'svc_diag_leak', categoryKey: 'diagnostics', categoryName: 'Диагностика', name: 'Поиск утечек ОЖ / масла / топлива', defaultDurationMinutes: 90, sortOrder: 50, requiredSkill: 'DIAGNOSTICS' },
  { id: 'svc_diag_noise', categoryKey: 'diagnostics', categoryName: 'Диагностика', name: 'Диагностика посторонних шумов (ездовая)', defaultDurationMinutes: 60, sortOrder: 60, requiredSkill: 'DIAGNOSTICS' },
  { id: 'svc_diag_hybrid', categoryKey: 'diagnostics', categoryName: 'Диагностика', name: 'Диагностика гибридной / высоковольтной системы', defaultDurationMinutes: 90, sortOrder: 70, requiredSkill: 'DIAGNOSTICS' },

  // ——— Мойка: кузов и колёса ———
  { id: 'svc_cw_body_contact', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Комплексная контактная мойка кузова', defaultDurationMinutes: 45, sortOrder: 10 },
  { id: 'svc_cw_body_touchless', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Бесконтактная мойка кузова', defaultDurationMinutes: 30, sortOrder: 20 },
  { id: 'svc_cw_body_hand', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Мойка кузова вручную (двухфазная)', defaultDurationMinutes: 60, sortOrder: 30 },
  { id: 'svc_cw_underbody', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Мойка днища и колёсных ниш', defaultDurationMinutes: 30, sortOrder: 40 },
  { id: 'svc_cw_arches', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Мойка арок и рам (внедорожник / пикап)', defaultDurationMinutes: 30, sortOrder: 50 },
  { id: 'svc_cw_tire_black', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Чернение шин и пластика дисков', defaultDurationMinutes: 20, sortOrder: 60 },
  { id: 'svc_cw_wheel_acid', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Щелочная / кислотная очистка дисков от налёта', defaultDurationMinutes: 40, sortOrder: 70 },
  { id: 'svc_cw_wax_spray', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Нанесение воска или быстрого блеска на кузов', defaultDurationMinutes: 25, sortOrder: 80 },
  { id: 'svc_cw_rain', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Антидождь на стёкла (комплект)', defaultDurationMinutes: 35, sortOrder: 90 },
  { id: 'svc_cw_glass_in_out', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Мойка и полировка стёкол (снаружи и внутри)', defaultDurationMinutes: 40, sortOrder: 100 },
  { id: 'svc_cw_bitumen', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Удаление битума и металлических вкраплений с ЛКП', defaultDurationMinutes: 90, sortOrder: 110 },
  { id: 'svc_cw_bugs', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Удаление насекомых с кузова и стёкол', defaultDurationMinutes: 30, sortOrder: 120 },
  { id: 'svc_cw_clay', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Очистка ЛКП глиной (clay bar)', defaultDurationMinutes: 60, sortOrder: 130 },
  { id: 'svc_cw_van', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Мойка микроавтобуса / высокого кузова', defaultDurationMinutes: 60, sortOrder: 140 },
  { id: 'svc_cw_moto', categoryKey: 'car_wash_exterior', categoryName: 'Мойка: кузов и колёса', name: 'Мойка мотоцикла / квадроцикла', defaultDurationMinutes: 45, sortOrder: 150 },

  // ——— Мойка: салон и химчистка ———
  { id: 'svc_cw_int_basic', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Комплексная химчистка салона (без снятия сидений)', defaultDurationMinutes: 120, sortOrder: 10 },
  { id: 'svc_cw_int_partial_seat', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Химчистка с частичным снятием сидений', defaultDurationMinutes: 180, sortOrder: 20 },
  { id: 'svc_cw_int_full_seat', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Химчистка с полным снятием сидений', defaultDurationMinutes: 300, sortOrder: 30 },
  { id: 'svc_cw_int_dry', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Сухая чистка текстиля и ковров', defaultDurationMinutes: 60, sortOrder: 40 },
  { id: 'svc_cw_int_plastic', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Влажная уборка и матирование пластика салона', defaultDurationMinutes: 45, sortOrder: 50 },
  { id: 'svc_cw_int_plastic_pol', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Полировка пластика и торпедо (восстановление)', defaultDurationMinutes: 90, sortOrder: 60 },
  { id: 'svc_cw_int_crevices', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Очистка труднодоступных мест (щели, воздуховоды)', defaultDurationMinutes: 60, sortOrder: 70 },
  { id: 'svc_cw_int_leather', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Реставрация и покраска кожи (руль, сиденья)', defaultDurationMinutes: 120, sortOrder: 80 },
  { id: 'svc_cw_int_alcantara', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Глубокая чистка велюра и алькантары', defaultDurationMinutes: 90, sortOrder: 90 },
  { id: 'svc_cw_int_headliner', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Чистка потолка (без деформации обивки)', defaultDurationMinutes: 90, sortOrder: 100 },
  { id: 'svc_cw_int_ozone', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Озонирование салона', defaultDurationMinutes: 45, sortOrder: 110 },
  { id: 'svc_cw_int_odor', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Удаление запаха (табак, животные, проливы)', defaultDurationMinutes: 120, sortOrder: 120 },
  { id: 'svc_cw_int_trunk', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Чистка багажника и ниши запасного колеса', defaultDurationMinutes: 45, sortOrder: 130 },
  { id: 'svc_cw_int_cond_leather', categoryKey: 'car_wash_interior', categoryName: 'Салон и химчистка', name: 'Кондиционирование кожи салона', defaultDurationMinutes: 40, sortOrder: 140 },

  // ——— Мойка: дополнительно ———
  { id: 'svc_cw_eng_steam', categoryKey: 'car_wash_extra', categoryName: 'Мойка: дополнительно', name: 'Мойка моторного отсека (пар / щадящая)', defaultDurationMinutes: 45, sortOrder: 10 },
  { id: 'svc_cw_eng_detail', categoryKey: 'car_wash_extra', categoryName: 'Мойка: дополнительно', name: 'Детейлинг моторного отсека с консервацией', defaultDurationMinutes: 90, sortOrder: 20 },
  { id: 'svc_cw_presale', categoryKey: 'car_wash_extra', categoryName: 'Мойка: дополнительно', name: 'Предпродажная подготовка (кузов + салон)', defaultDurationMinutes: 360, sortOrder: 30 },
  { id: 'svc_cw_sticker', categoryKey: 'car_wash_extra', categoryName: 'Мойка: дополнительно', name: 'Снятие наклеек и следов клея', defaultDurationMinutes: 40, sortOrder: 40 },
  { id: 'svc_cw_tire_shine', categoryKey: 'car_wash_extra', categoryName: 'Мойка: дополнительно', name: 'Нанесение долговременного блеска на шины', defaultDurationMinutes: 15, sortOrder: 50 },

  // ——— Детейлинг: защита и покрытия ———
  { id: 'svc_det_wax_hard', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Нанесение твёрдого воска', defaultDurationMinutes: 120, sortOrder: 10, requiredSkill: 'BODY' },
  { id: 'svc_det_sealant', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Нанесение синтетического силанта', defaultDurationMinutes: 90, sortOrder: 20, requiredSkill: 'BODY' },
  { id: 'svc_det_liquid_glass', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Покрытие «жидкое стекло»', defaultDurationMinutes: 180, sortOrder: 30, requiredSkill: 'BODY' },
  { id: 'svc_det_ceramic_1', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Керамическое покрытие кузова (1 слой)', defaultDurationMinutes: 300, sortOrder: 40, requiredSkill: 'BODY' },
  { id: 'svc_det_ceramic_multi', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Керамическое покрытие кузова (многослойное)', defaultDurationMinutes: 480, sortOrder: 50, requiredSkill: 'BODY' },
  { id: 'svc_det_ceramic_glass', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Керамика на стёкла и пластик', defaultDurationMinutes: 120, sortOrder: 60, requiredSkill: 'BODY' },
  { id: 'svc_det_ppf_local', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Оклейка антигравийной плёнкой (локально)', defaultDurationMinutes: 180, sortOrder: 70, requiredSkill: 'BODY' },
  { id: 'svc_det_ppf_full', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Оклейка кузова антигравийной плёнкой (полная)', defaultDurationMinutes: 1440, sortOrder: 80, requiredSkill: 'BODY' },
  { id: 'svc_det_film_lights', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Бронирование / тонировка фар плёнкой', defaultDurationMinutes: 90, sortOrder: 90, requiredSkill: 'BODY' },
  { id: 'svc_det_leather_coat', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Защитное покрытие кожи салона', defaultDurationMinutes: 90, sortOrder: 100 },
  { id: 'svc_det_sill_film', categoryKey: 'detailing_coating', categoryName: 'Детейлинг: защита ЛКП', name: 'Оклейка порогов и зон риска плёнкой', defaultDurationMinutes: 60, sortOrder: 110 },

  // ——— Детейлинг: коррекция ———
  { id: 'svc_det_polish_1step', categoryKey: 'detailing_correction', categoryName: 'Детейлинг: коррекция ЛКП', name: 'Абразивная полировка кузова (одношаговая)', defaultDurationMinutes: 240, sortOrder: 10, requiredSkill: 'BODY' },
  { id: 'svc_det_polish_2step', categoryKey: 'detailing_correction', categoryName: 'Детейлинг: коррекция ЛКП', name: 'Полировка кузова в два этапа (коррекция + финиш)', defaultDurationMinutes: 480, sortOrder: 20, requiredSkill: 'BODY' },
  { id: 'svc_det_prep_coat', categoryKey: 'detailing_correction', categoryName: 'Детейлинг: коррекция ЛКП', name: 'Подготовка ЛКП к покрытию (обезжиривание, IPA)', defaultDurationMinutes: 60, sortOrder: 30, requiredSkill: 'BODY' },
  { id: 'svc_det_headlight', categoryKey: 'detailing_correction', categoryName: 'Детейлинг: коррекция ЛКП', name: 'Полировка и восстановление прозрачности фар', defaultDurationMinutes: 90, sortOrder: 40, requiredSkill: 'BODY' },
  { id: 'svc_det_chrome', categoryKey: 'detailing_correction', categoryName: 'Детейлинг: коррекция ЛКП', name: 'Полировка хрома и декоративных накладок', defaultDurationMinutes: 60, sortOrder: 50, requiredSkill: 'BODY' },
  { id: 'svc_det_hologram', categoryKey: 'detailing_correction', categoryName: 'Детейлинг: коррекция ЛКП', name: 'Удаление голограмм и микроповреждений ЛКП', defaultDurationMinutes: 300, sortOrder: 60, requiredSkill: 'BODY' },

  // ——— Автозвук и электроника ———
  { id: 'svc_ca_head_unit', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Установка головного устройства (1 DIN / 2 DIN)', defaultDurationMinutes: 90, sortOrder: 10, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_amp', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Установка усилителя', defaultDurationMinutes: 120, sortOrder: 20, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_sub', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Установка сабвуфера (активного или пассивного)', defaultDurationMinutes: 120, sortOrder: 30, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_sub_box', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Изготовление и установка короба под сабвуфер', defaultDurationMinutes: 240, sortOrder: 40, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_speakers', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Замена / установка компонентной акустики', defaultDurationMinutes: 180, sortOrder: 50, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_noise_door', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Шумоизоляция дверей', defaultDurationMinutes: 180, sortOrder: 60 },
  { id: 'svc_ca_noise_floor', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Шумоизоляция пола и арок', defaultDurationMinutes: 480, sortOrder: 70 },
  { id: 'svc_ca_noise_hood', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Шумоизоляция капота и багажника', defaultDurationMinutes: 120, sortOrder: 80 },
  { id: 'svc_ca_camera', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Установка камеры заднего / кругового обзора', defaultDurationMinutes: 120, sortOrder: 90, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_alarm', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Установка сигнализации с автозапуском', defaultDurationMinutes: 180, sortOrder: 100, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_dsp', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Установка и настройка DSP / процессора', defaultDurationMinutes: 240, sortOrder: 110, requiredSkill: 'ELECTRICAL' },
  { id: 'svc_ca_key_prog', categoryKey: 'car_audio_install', categoryName: 'Автозвук и электроника', name: 'Программирование брелоков и ключей', defaultDurationMinutes: 60, sortOrder: 120, requiredSkill: 'ELECTRICAL' },

  // ——— Стёкла ———
  { id: 'svc_gl_chip', categoryKey: 'glass_services', categoryName: 'Стёкла', name: 'Ремонт скола / трещины лобового стекла', defaultDurationMinutes: 45, sortOrder: 10 },
  { id: 'svc_gl_polish', categoryKey: 'glass_services', categoryName: 'Стёкла', name: 'Полировка стёкол (царапины, известковый налёт)', defaultDurationMinutes: 60, sortOrder: 20 },
  { id: 'svc_gl_windshield', categoryKey: 'glass_services', categoryName: 'Стёкла', name: 'Замена лобового стекла', defaultDurationMinutes: 120, sortOrder: 30 },
  { id: 'svc_gl_side', categoryKey: 'glass_services', categoryName: 'Стёкла', name: 'Замена бокового стекла', defaultDurationMinutes: 90, sortOrder: 40 },
  { id: 'svc_gl_rear', categoryKey: 'glass_services', categoryName: 'Стёкла', name: 'Замена заднего стекла', defaultDurationMinutes: 120, sortOrder: 50 },
  { id: 'svc_gl_molding', categoryKey: 'glass_services', categoryName: 'Стёкла', name: 'Снятие / установка молдингов стёкол', defaultDurationMinutes: 45, sortOrder: 60 },
  { id: 'svc_gl_seal', categoryKey: 'glass_services', categoryName: 'Стёкла', name: 'Герметизация и устранение продувания стёкол', defaultDurationMinutes: 60, sortOrder: 70 },
];
