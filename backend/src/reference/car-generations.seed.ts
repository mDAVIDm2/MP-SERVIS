/**
 * Поколения моделей автомобилей. Ключ: "brandName|modelName", значение: массив поколений.
 * Используется после сида марок и моделей: ищем modelId по brandName + modelName и вставляем поколения.
 */
export interface GenerationSeed {
  name: string;
  yearFrom?: number;
  yearTo?: number;
}

export const CAR_GENERATIONS_SEED: { brandName: string; modelName: string; generations: GenerationSeed[] }[] = [
  // Toyota
  { brandName: 'Toyota', modelName: 'Camry', generations: [
    { name: 'XV70 (8-е поколение)', yearFrom: 2017, yearTo: 2024 },
    { name: 'XV50 (7-е поколение)', yearFrom: 2011, yearTo: 2017 },
    { name: 'XV40 (6-е поколение)', yearFrom: 2006, yearTo: 2011 },
    { name: 'XV30 (5-е поколение)', yearFrom: 2001, yearTo: 2006 },
    { name: 'XV20 (4-е поколение)', yearFrom: 1996, yearTo: 2001 },
  ]},
  { brandName: 'Toyota', modelName: 'Corolla', generations: [
    { name: 'E210 (12-е поколение)', yearFrom: 2018, yearTo: 2023 },
    { name: 'E170 (11-е поколение)', yearFrom: 2013, yearTo: 2019 },
    { name: 'E150 (10-е поколение)', yearFrom: 2006, yearTo: 2013 },
    { name: 'E120 (9-е поколение)', yearFrom: 2000, yearTo: 2007 },
  ]},
  { brandName: 'Toyota', modelName: 'RAV4', generations: [
    { name: 'XA50 (5-е поколение)', yearFrom: 2018, yearTo: 2024 },
    { name: 'XA40 (4-е поколение)', yearFrom: 2012, yearTo: 2018 },
    { name: 'XA30 (3-е поколение)', yearFrom: 2005, yearTo: 2012 },
  ]},
  { brandName: 'Toyota', modelName: 'Land Cruiser', generations: [
    { name: 'J300 (3-е поколение)', yearFrom: 2021 },
    { name: 'J200 (2-е поколение)', yearFrom: 2007, yearTo: 2021 },
    { name: 'J100 (1-е поколение)', yearFrom: 1998, yearTo: 2007 },
  ]},
  { brandName: 'Toyota', modelName: 'Land Cruiser Prado', generations: [
    { name: 'J150 (4-е поколение)', yearFrom: 2009 },
    { name: 'J120 (3-е поколение)', yearFrom: 2002, yearTo: 2009 },
  ]},
  { brandName: 'Toyota', modelName: 'Yaris', generations: [
    { name: 'XP210 (4-е поколение)', yearFrom: 2019 },
    { name: 'XP150 (3-е поколение)', yearFrom: 2010, yearTo: 2019 },
    { name: 'XP90 (2-е поколение)', yearFrom: 2005, yearTo: 2011 },
  ]},
  // Lada
  { brandName: 'Lada', modelName: 'Vesta', generations: [
    { name: 'Vesta 2 (рестайлинг)', yearFrom: 2022 },
    { name: 'Vesta 1', yearFrom: 2015, yearTo: 2022 },
  ]},
  { brandName: 'Lada', modelName: 'Granta', generations: [
    { name: 'Granta 2 (рестайлинг)', yearFrom: 2018 },
    { name: 'Granta 1', yearFrom: 2011, yearTo: 2018 },
  ]},
  { brandName: 'Lada', modelName: 'XRAY', generations: [
    { name: 'XRAY', yearFrom: 2015 },
  ]},
  { brandName: 'Lada', modelName: 'Niva', generations: [
    { name: 'Niva Legend (2121)', yearFrom: 1977 },
    { name: 'Niva Travel', yearFrom: 2020 },
  ]},
  // Hyundai
  { brandName: 'Hyundai', modelName: 'Solaris', generations: [
    { name: 'HC (2-е поколение, рестайлинг)', yearFrom: 2020 },
    { name: 'HC (2-е поколение)', yearFrom: 2017, yearTo: 2020 },
    { name: 'RB (1-е поколение)', yearFrom: 2010, yearTo: 2017 },
  ]},
  { brandName: 'Hyundai', modelName: 'Creta', generations: [
    { name: '2-е поколение (рестайлинг)', yearFrom: 2023 },
    { name: '2-е поколение', yearFrom: 2020, yearTo: 2023 },
    { name: '1-е поколение', yearFrom: 2016, yearTo: 2020 },
  ]},
  { brandName: 'Hyundai', modelName: 'Tucson', generations: [
    { name: 'NX4 (4-е поколение)', yearFrom: 2020 },
    { name: 'TL (3-е поколение)', yearFrom: 2015, yearTo: 2020 },
    { name: 'LM (2-е поколение)', yearFrom: 2009, yearTo: 2015 },
  ]},
  { brandName: 'Hyundai', modelName: 'Sonata', generations: [
    { name: 'DN8 (8-е поколение)', yearFrom: 2019 },
    { name: 'LF (7-е поколение)', yearFrom: 2014, yearTo: 2019 },
    { name: 'YF (6-е поколение)', yearFrom: 2009, yearTo: 2014 },
  ]},
  { brandName: 'Hyundai', modelName: 'Elantra', generations: [
    { name: 'CN7 (7-е поколение)', yearFrom: 2020 },
    { name: 'AD (6-е поколение)', yearFrom: 2015, yearTo: 2020 },
    { name: 'MD (5-е поколение)', yearFrom: 2010, yearTo: 2015 },
  ]},
  // Kia
  { brandName: 'Kia', modelName: 'Rio', generations: [
    { name: 'QB (4-е поколение, рестайлинг)', yearFrom: 2020 },
    { name: 'QB (4-е поколение)', yearFrom: 2017, yearTo: 2020 },
    { name: 'UB (3-е поколение)', yearFrom: 2011, yearTo: 2017 },
    { name: 'JB (2-е поколение)', yearFrom: 2005, yearTo: 2011 },
  ]},
  { brandName: 'Kia', modelName: 'Sportage', generations: [
    { name: 'NQ5 (5-е поколение)', yearFrom: 2021 },
    { name: 'QL (4-е поколение)', yearFrom: 2015, yearTo: 2021 },
    { name: 'SL (3-е поколение)', yearFrom: 2010, yearTo: 2015 },
    { name: 'KM (2-е поколение)', yearFrom: 2004, yearTo: 2010 },
  ]},
  { brandName: 'Kia', modelName: 'Sorento', generations: [
    { name: 'MQ4 (4-е поколение)', yearFrom: 2020 },
    { name: 'UM (3-е поколение)', yearFrom: 2014, yearTo: 2020 },
    { name: 'XM (2-е поколение)', yearFrom: 2009, yearTo: 2014 },
  ]},
  { brandName: 'Kia', modelName: 'Optima', generations: [
    { name: 'JF (4-е поколение)', yearFrom: 2015, yearTo: 2020 },
    { name: 'TF (3-е поколение)', yearFrom: 2010, yearTo: 2015 },
  ]},
  // Volkswagen
  { brandName: 'Volkswagen', modelName: 'Polo', generations: [
    { name: '6-е поколение (рестайлинг)', yearFrom: 2021 },
    { name: '6-е поколение', yearFrom: 2017, yearTo: 2021 },
    { name: '5-е поколение (6c)', yearFrom: 2009, yearTo: 2017 },
    { name: '5-е поколение (6)', yearFrom: 2005, yearTo: 2009 },
  ]},
  { brandName: 'Volkswagen', modelName: 'Tiguan', generations: [
    { name: 'BWD (2-е поколение, рестайлинг)', yearFrom: 2020 },
    { name: 'BWD (2-е поколение)', yearFrom: 2016, yearTo: 2020 },
    { name: '5N (1-е поколение)', yearFrom: 2007, yearTo: 2016 },
  ]},
  { brandName: 'Volkswagen', modelName: 'Passat', generations: [
    { name: 'B8 (8-е поколение, рестайлинг)', yearFrom: 2019 },
    { name: 'B8 (8-е поколение)', yearFrom: 2014, yearTo: 2019 },
    { name: 'B7 (7-е поколение)', yearFrom: 2010, yearTo: 2014 },
    { name: 'B6 (6-е поколение)', yearFrom: 2005, yearTo: 2010 },
  ]},
  { brandName: 'Volkswagen', modelName: 'Golf', generations: [
    { name: 'Mk8 (8-е поколение)', yearFrom: 2019 },
    { name: 'Mk7 (7-е поколение)', yearFrom: 2012, yearTo: 2020 },
    { name: 'Mk6 (6-е поколение)', yearFrom: 2008, yearTo: 2012 },
    { name: 'Mk5 (5-е поколение)', yearFrom: 2003, yearTo: 2008 },
  ]},
  // Skoda
  { brandName: 'Skoda', modelName: 'Octavia', generations: [
    { name: '4-е поколение (рестайлинг)', yearFrom: 2023 },
    { name: '4-е поколение', yearFrom: 2019, yearTo: 2023 },
    { name: '3-е поколение', yearFrom: 2012, yearTo: 2019 },
    { name: '2-е поколение', yearFrom: 2004, yearTo: 2012 },
  ]},
  { brandName: 'Skoda', modelName: 'Rapid', generations: [
    { name: 'Рестайлинг', yearFrom: 2017 },
    { name: '1-е поколение', yearFrom: 2012, yearTo: 2017 },
  ]},
  { brandName: 'Skoda', modelName: 'Kodiaq', generations: [
    { name: 'Рестайлинг', yearFrom: 2021 },
    { name: '1-е поколение', yearFrom: 2016, yearTo: 2021 },
  ]},
  // Renault
  { brandName: 'Renault', modelName: 'Logan', generations: [
    { name: '3-е поколение', yearFrom: 2022 },
    { name: '2-е поколение', yearFrom: 2012, yearTo: 2022 },
    { name: '1-е поколение', yearFrom: 2004, yearTo: 2012 },
  ]},
  { brandName: 'Renault', modelName: 'Duster', generations: [
    { name: '2-е поколение (рестайлинг)', yearFrom: 2021 },
    { name: '2-е поколение', yearFrom: 2017, yearTo: 2021 },
    { name: '1-е поколение', yearFrom: 2010, yearTo: 2017 },
  ]},
  { brandName: 'Renault', modelName: 'Sandero', generations: [
    { name: '3-е поколение', yearFrom: 2021 },
    { name: '2-е поколение', yearFrom: 2012, yearTo: 2021 },
    { name: '1-е поколение', yearFrom: 2007, yearTo: 2012 },
  ]},
  { brandName: 'Renault', modelName: 'Kaptur', generations: [
    { name: 'Рестайлинг', yearFrom: 2022 },
    { name: '1-е поколение', yearFrom: 2016, yearTo: 2022 },
  ]},
  // Nissan
  { brandName: 'Nissan', modelName: 'Qashqai', generations: [
    { name: '3-е поколение (J12)', yearFrom: 2021 },
    { name: '2-е поколение (J11)', yearFrom: 2013, yearTo: 2021 },
    { name: '1-е поколение (J10)', yearFrom: 2006, yearTo: 2013 },
  ]},
  { brandName: 'Nissan', modelName: 'X-Trail', generations: [
    { name: '4-е поколение (T33)', yearFrom: 2021 },
    { name: '3-е поколение (T32)', yearFrom: 2013, yearTo: 2021 },
    { name: '2-е поколение (T31)', yearFrom: 2007, yearTo: 2013 },
    { name: '1-е поколение (T30)', yearFrom: 2000, yearTo: 2007 },
  ]},
  { brandName: 'Nissan', modelName: 'Patrol', generations: [
    { name: 'Y62 (6-е поколение)', yearFrom: 2010 },
    { name: 'Y61 (5-е поколение)', yearFrom: 1997, yearTo: 2010 },
  ]},
  // BMW
  { brandName: 'BMW', modelName: '3', generations: [
    { name: 'G20/G21 (7-е поколение)', yearFrom: 2018 },
    { name: 'F30/F31 (6-е поколение)', yearFrom: 2011, yearTo: 2019 },
    { name: 'E90/E91 (5-е поколение)', yearFrom: 2005, yearTo: 2011 },
  ]},
  { brandName: 'BMW', modelName: '5', generations: [
    { name: 'G30/G31 (7-е поколение)', yearFrom: 2016 },
    { name: 'F10/F11 (6-е поколение)', yearFrom: 2010, yearTo: 2017 },
    { name: 'E60/E61 (5-е поколение)', yearFrom: 2003, yearTo: 2010 },
  ]},
  { brandName: 'BMW', modelName: 'X3', generations: [
    { name: 'G01 (3-е поколение)', yearFrom: 2017 },
    { name: 'F25 (2-е поколение)', yearFrom: 2010, yearTo: 2017 },
    { name: 'E83 (1-е поколение)', yearFrom: 2003, yearTo: 2010 },
  ]},
  { brandName: 'BMW', modelName: 'X5', generations: [
    { name: 'G05 (4-е поколение)', yearFrom: 2018 },
    { name: 'F15 (3-е поколение)', yearFrom: 2013, yearTo: 2018 },
    { name: 'E70 (2-е поколение)', yearFrom: 2006, yearTo: 2013 },
    { name: 'E53 (1-е поколение)', yearFrom: 1999, yearTo: 2006 },
  ]},
  // Mercedes-Benz
  { brandName: 'Mercedes-Benz', modelName: 'C-Class', generations: [
    { name: 'W206 (5-е поколение)', yearFrom: 2021 },
    { name: 'W205 (4-е поколение)', yearFrom: 2014, yearTo: 2021 },
    { name: 'W204 (3-е поколение)', yearFrom: 2007, yearTo: 2014 },
  ]},
  { brandName: 'Mercedes-Benz', modelName: 'E-Class', generations: [
    { name: 'W214 (6-е поколение)', yearFrom: 2023 },
    { name: 'W213 (5-е поколение)', yearFrom: 2016, yearTo: 2023 },
    { name: 'W212 (4-е поколение)', yearFrom: 2009, yearTo: 2016 },
  ]},
  { brandName: 'Mercedes-Benz', modelName: 'GLC', generations: [
    { name: 'X254 (2-е поколение)', yearFrom: 2022 },
    { name: 'X253 (1-е поколение)', yearFrom: 2015, yearTo: 2022 },
  ]},
  // Audi
  { brandName: 'Audi', modelName: 'A4', generations: [
    { name: 'B9 (5-е поколение, рестайлинг)', yearFrom: 2019 },
    { name: 'B9 (5-е поколение)', yearFrom: 2015, yearTo: 2019 },
    { name: 'B8 (4-е поколение)', yearFrom: 2008, yearTo: 2015 },
  ]},
  { brandName: 'Audi', modelName: 'A6', generations: [
    { name: 'C8 (5-е поколение)', yearFrom: 2018 },
    { name: 'C7 (4-е поколение)', yearFrom: 2011, yearTo: 2018 },
    { name: 'C6 (3-е поколение)', yearFrom: 2004, yearTo: 2011 },
  ]},
  { brandName: 'Audi', modelName: 'Q5', generations: [
    { name: 'FY (2-е поколение, рестайлинг)', yearFrom: 2020 },
    { name: 'FY (2-е поколение)', yearFrom: 2016, yearTo: 2020 },
    { name: '8R (1-е поколение)', yearFrom: 2008, yearTo: 2016 },
  ]},
  // Mazda
  { brandName: 'Mazda', modelName: '3', generations: [
    { name: 'BP (4-е поколение)', yearFrom: 2019 },
    { name: 'BM (3-е поколение)', yearFrom: 2013, yearTo: 2019 },
    { name: 'BL (2-е поколение)', yearFrom: 2008, yearTo: 2013 },
  ]},
  { brandName: 'Mazda', modelName: '6', generations: [
    { name: 'GJ (3-е поколение)', yearFrom: 2012 },
    { name: 'GH (2-е поколение)', yearFrom: 2007, yearTo: 2012 },
  ]},
  { brandName: 'Mazda', modelName: 'CX-5', generations: [
    { name: 'KF (2-е поколение)', yearFrom: 2016 },
    { name: 'KE (1-е поколение)', yearFrom: 2012, yearTo: 2016 },
  ]},
  // Ford
  { brandName: 'Ford', modelName: 'Focus', generations: [
    { name: '4-е поколение', yearFrom: 2018 },
    { name: '3-е поколение', yearFrom: 2010, yearTo: 2018 },
    { name: '2-е поколение', yearFrom: 2004, yearTo: 2010 },
  ]},
  { brandName: 'Ford', modelName: 'Kuga', generations: [
    { name: '4-е поколение', yearFrom: 2020 },
    { name: '3-е поколение', yearFrom: 2012, yearTo: 2020 },
    { name: '2-е поколение', yearFrom: 2008, yearTo: 2012 },
  ]},
  // Chevrolet
  { brandName: 'Chevrolet', modelName: 'Niva', generations: [
    { name: '2-е поколение', yearFrom: 2020 },
    { name: '1-е поколение', yearFrom: 2002, yearTo: 2020 },
  ]},
  { brandName: 'Chevrolet', modelName: 'Cruze', generations: [
    { name: '2-е поколение', yearFrom: 2016, yearTo: 2019 },
    { name: '1-е поколение', yearFrom: 2008, yearTo: 2016 },
  ]},
  // Honda
  { brandName: 'Honda', modelName: 'Civic', generations: [
    { name: '11-е поколение', yearFrom: 2021 },
    { name: '10-е поколение', yearFrom: 2015, yearTo: 2021 },
    { name: '9-е поколение', yearFrom: 2011, yearTo: 2015 },
  ]},
  { brandName: 'Honda', modelName: 'CR-V', generations: [
    { name: '6-е поколение', yearFrom: 2022 },
    { name: '5-е поколение', yearFrom: 2016, yearTo: 2022 },
    { name: '4-е поколение', yearFrom: 2011, yearTo: 2016 },
  ]},
  // Mitsubishi
  { brandName: 'Mitsubishi', modelName: 'Outlander', generations: [
    { name: '4-е поколение', yearFrom: 2021 },
    { name: '3-е поколение', yearFrom: 2012, yearTo: 2021 },
    { name: '2-е поколение', yearFrom: 2005, yearTo: 2012 },
  ]},
  { brandName: 'Mitsubishi', modelName: 'Pajero Sport', generations: [
    { name: '3-е поколение', yearFrom: 2015 },
    { name: '2-е поколение', yearFrom: 2008, yearTo: 2015 },
  ]},
  // UAZ
  { brandName: 'UAZ', modelName: 'Patriot', generations: [
    { name: 'Рестайлинг', yearFrom: 2016 },
    { name: '1-е поколение', yearFrom: 2005, yearTo: 2016 },
  ]},
  { brandName: 'UAZ', modelName: 'Hunter', generations: [
    { name: 'Hunter', yearFrom: 2003 },
  ]},
  // Geely, Haval, Chery — по одной записи для типичных моделей
  { brandName: 'Geely', modelName: 'Coolray', generations: [
    { name: '1-е поколение', yearFrom: 2019 },
  ]},
  { brandName: 'Haval', modelName: 'F7', generations: [
    { name: '1-е поколение', yearFrom: 2018 },
  ]},
  { brandName: 'Haval', modelName: 'H6', generations: [
    { name: '3-е поколение', yearFrom: 2020 },
    { name: '2-е поколение', yearFrom: 2017, yearTo: 2020 },
    { name: '1-е поколение', yearFrom: 2011, yearTo: 2017 },
  ]},
  { brandName: 'Chery', modelName: 'Tiggo 7', generations: [
    { name: 'Pro', yearFrom: 2020 },
    { name: '1-е поколение', yearFrom: 2016, yearTo: 2020 },
  ]},
  { brandName: 'Chery', modelName: 'Tiggo 8', generations: [
    { name: 'Pro Max', yearFrom: 2023 },
    { name: 'Pro', yearFrom: 2020, yearTo: 2023 },
    { name: '1-е поколение', yearFrom: 2018, yearTo: 2020 },
  ]},
];
