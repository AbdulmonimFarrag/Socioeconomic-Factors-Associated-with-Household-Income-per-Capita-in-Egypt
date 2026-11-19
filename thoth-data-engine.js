'use strict';

const fs = require('fs');

const ARABIC_GOVERNORATES = {
  Alexandria: ['alexandria', 'اسكندرية', 'الاسكندرية'],
  Assiut: ['assiut', 'asyut', 'اسيوط'],
  Aswan: ['aswan', 'اسوان'],
  'Bani Swef': ['bani swef', 'beni suef', 'بني سويف'],
  Beheira: ['beheira', 'behera', 'البحيرة'],
  Cairo: ['cairo', 'القاهرة', 'القاهره'],
  Dakahlia: ['dakahlia', 'الدقهلية', 'الدقهليه'],
  Damietta: ['damietta', 'دمياط'],
  'ElBahr ElAhmar': ['red sea', 'el bahr el ahmar', 'البحر الاحمر'],
  'ElWadi ElGadid': ['new valley', 'el wadi el gadid', 'الوادي الجديد'],
  Fayoum: ['fayoum', 'faiyum', 'الفيوم'],
  Gharbia: ['gharbia', 'الغربية', 'الغربيه'],
  Giza: ['giza', 'الجيزة', 'الجيزه'],
  Ismailya: ['ismailia', 'ismailya', 'الاسماعيلية', 'الاسماعيليه'],
  'Kafr Elsheikh': ['kafr el sheikh', 'kafr elsheikh', 'كفر الشيخ'],
  Luxor: ['luxor', 'الاقصر'],
  Matrouh: ['matrouh', 'matruh', 'مطروح'],
  Menia: ['minya', 'menia', 'المنيا'],
  Monofia: ['monufia', 'monofia', 'المنوفية', 'المنوفيه'],
  'Port Said': ['port said', 'بورسعيد', 'بور سعيد'],
  Qena: ['qena', 'قنا'],
  Qualioubia: ['qalyubia', 'qualioubia', 'القليوبية', 'القليوبيه'],
  Sharkia: ['sharkia', 'الشرقية', 'الشرقيه'],
  Sohag: ['sohag', 'سوهاج'],
  'South Sinai': ['south sinai', 'جنوب سيناء'],
  Suez: ['suez', 'السويس']
};

const METRICS = [
  { id: 'income', name: 'Average annual household income', kind: 'h', unit: 'EGP/year', aliases: ['income', 'household income', 'annual income', 'دخل', 'الدخل'], calc: h => div(h.inc, h.w) },
  { id: 'spending', name: 'Average annual household spending', kind: 'h', unit: 'EGP/year', aliases: ['spending', 'expenditure', 'مصروفات', 'الانفاق', 'إنفاق'], calc: h => div(h.exp, h.w) },
  { id: 'savings', name: 'Household savings rate', kind: 'h', unit: '%', aliases: ['saving', 'savings', 'ادخار', 'التوفير'], calc: h => pct(h.inc - h.exp, h.inc) },
  { id: 'food', name: 'Food share of spending', kind: 'h', unit: '%', aliases: ['food', 'food share', 'اكل', 'الأكل', 'الغذاء', 'طعام'], calc: h => pct(h.food, h.exp) },
  { id: 'housing', name: 'Housing share of spending', kind: 'h', unit: '%', aliases: ['housing', 'rent', 'سكن', 'السكن', 'ايجار'], calc: h => pct(h.hous, h.exp) },
  { id: 'health_spending', name: 'Health share of spending', kind: 'h', unit: '%', aliases: ['health spending', 'medical spending', 'انفاق صحي', 'الصحة'], calc: h => pct(h.hlth, h.exp) },
  { id: 'education_spending', name: 'Education share of spending', kind: 'h', unit: '%', aliases: ['education spending', 'school spending', 'انفاق التعليم', 'مصاريف التعليم'], calc: h => pct(h.edu, h.exp) },
  { id: 'transport', name: 'Transport share of spending', kind: 'h', unit: '%', aliases: ['transport', 'transportation', 'مواصلات', 'النقل'], calc: h => pct(h.trn, h.exp) },
  { id: 'internet', name: 'Households with internet access', kind: 'h', unit: '%', aliases: ['internet', 'online', 'انترنت', 'الإنترنت'], calc: h => pct(h.net, h.w) },
  { id: 'piped_water', name: 'Households with piped water', kind: 'h', unit: '%', aliases: ['piped water', 'water access', 'مياه', 'المياه', 'مياه مواسير'], calc: h => pct(h.pipe, h.w) },
  { id: 'remittances', name: 'Remittance-reliant households', kind: 'h', unit: '%', aliases: ['remittance', 'transfers', 'تحويلات', 'حوالات'], calc: h => pct(h.s2, h.w) },
  { id: 'wages', name: 'Households relying on wages', kind: 'h', unit: '%', aliases: ['wage', 'salary', 'salaries', 'مرتب', 'رواتب', 'اجور'], calc: h => pct(h.s0, h.w) },
  { id: 'business', name: 'Households relying on own business', kind: 'h', unit: '%', aliases: ['business income', 'own business', 'مشروع', 'اعمال خاصة'], calc: h => pct(h.s1, h.w) },
  { id: 'household_size', name: 'Average household size', kind: 'h', unit: 'people/household', aliases: ['household size', 'family size', 'حجم الاسرة', 'عدد افراد الاسرة'], calc: h => div(h.p, h.w) },
  { id: 'earners', name: 'Average earners per household', kind: 'h', unit: 'earners/household', aliases: ['earners', 'income earners', 'عاملين في الاسرة', 'المعيلين'], calc: h => div(h.e, h.w) },
  { id: 'literacy', name: 'Literacy rate age 10+', kind: 'i', unit: '%', aliases: ['literacy', 'literate', 'قراءة', 'كتابة', 'محو الامية', 'الأمية'], calc: i => pct(i.lit, i.litD) },
  { id: 'insurance', name: 'Health insurance coverage', kind: 'i', unit: '%', aliases: ['insurance', 'health insurance', 'تأمين', 'التأمين الصحي'], calc: i => pct(i.ins, i.w) },
  { id: 'enrolment', name: 'School enrolment age 6-17', kind: 'i', unit: '%', aliases: ['enrolment', 'school enrollment', 'school attendance', 'التحاق', 'التعليم', 'المدرسة'], calc: i => pct(i.s17y, i.s17) },
  { id: 'unemployment', name: 'Unemployment rate', kind: 'i', unit: '%', aliases: ['unemployment', 'unemployed', 'بطالة', 'البطاله'], calc: i => pct(i.une, i.emp + i.une) },
  { id: 'labour', name: 'Labour force participation', kind: 'i', unit: '%', aliases: ['labour participation', 'labor participation', 'work participation', 'قوة العمل', 'المشاركة في العمل'], calc: i => pct(i.act, i.lfD) },
  { id: 'chronic', name: 'Chronic disease prevalence', kind: 'i', unit: '%', aliases: ['chronic disease', 'chronic illness', 'امراض مزمنة', 'مرض مزمن'], calc: i => pct(i.chr, i.w) },
  { id: 'disability', name: 'Disability prevalence', kind: 'i', unit: '%', aliases: ['disability', 'disabled', 'اعاقة', 'ذوي الاعاقة'], calc: i => pct(i.dis, i.w) },
  { id: 'secondary_education', name: 'Adults 25+ with secondary education', kind: 'i', unit: '%', aliases: ['secondary education', 'ثانوي', 'تعليم ثانوي'], calc: i => pct(i.e2, i.e25) },
  { id: 'university', name: 'Adults 25+ with university education', kind: 'i', unit: '%', aliases: ['university', 'higher education', 'جامعة', 'جامعي', 'تعليم عالي'], calc: i => pct(i.e4, i.e25) }
];

const ASSETS = [
  ['Mobile phone', 'ph', ['mobile', 'phone', 'موبايل', 'هاتف']],
  ['Television', 'tv', ['tv', 'television', 'تلفزيون']],
  ['Refrigerator', 'fr', ['refrigerator', 'fridge', 'ثلاجة']],
  ['Washing machine', 'wm', ['washing machine', 'غسالة']],
  ['Satellite dish', 'sat', ['satellite', 'dish', 'دش']],
  ['Water heater', 'wh', ['water heater', 'سخان']],
  ['Computer', 'pc', ['computer', 'pc', 'كمبيوتر']],
  ['Air conditioner', 'ac', ['air conditioner', 'ac', 'تكييف']],
  ['Car or vehicle', 'car', ['car', 'vehicle', 'سيارة']]
];

for (const [name, key, aliases] of ASSETS) {
  METRICS.push({ id: `asset_${key}`, name: `Households owning ${name}`, kind: 'h', unit: '%', aliases, calc: h => pct(h[key], h.w) });
}

function div(a, b) { return b > 0 ? a / b : NaN; }
function pct(a, b) { return b > 0 ? (100 * a) / b : NaN; }
function round(value, digits = 1) { return Number.isFinite(value) ? Number(value.toFixed(digits)) : null; }
function normalize(value) {
  return String(value || '').toLowerCase()
    .normalize('NFKD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[أإآ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي')
    .replace(/[^a-z0-9\u0600-\u06ff%]+/g, ' ').replace(/\s+/g, ' ').trim();
}

function extractJson(source, name, nextName) {
  const prefix = `const ${name}=`;
  const start = source.indexOf(prefix);
  if (start < 0) throw new Error(`Dashboard dataset ${name} was not found.`);
  const valueStart = start + prefix.length;
  const markers = [`;\nconst ${nextName}=`, `;\r\nconst ${nextName}=`];
  const ends = markers.map(marker => source.indexOf(marker, valueStart)).filter(index => index >= 0);
  const end = ends.length ? Math.min(...ends) : -1;
  if (end < 0) throw new Error(`Dashboard dataset ${name} has no closing marker.`);
  return JSON.parse(source.slice(valueStart, end));
}

function scoreText(query, labels) {
  let score = 0;
  const words = new Set(query.split(' ').filter(word => word.length > 2));
  for (const label of labels) {
    const normalized = normalize(label);
    if (!normalized) continue;
    if (query.includes(normalized)) score = Math.max(score, 20 + normalized.length);
    let overlap = 0;
    for (const word of normalized.split(' ')) if (words.has(word)) overlap += word.length;
    score = Math.max(score, overlap);
  }
  return score;
}

function editDistance(a, b) {
  const left = normalize(a), right = normalize(b);
  const row = Array.from({ length: right.length + 1 }, (_, index) => index);
  for (let i = 1; i <= left.length; i += 1) {
    let diagonal = row[0];
    row[0] = i;
    for (let j = 1; j <= right.length; j += 1) {
      const above = row[j];
      row[j] = Math.min(row[j] + 1, row[j - 1] + 1, diagonal + (left[i - 1] === right[j - 1] ? 0 : 1));
      diagonal = above;
    }
  }
  return row[right.length];
}

function fuzzyLabelScore(query, label) {
  const qWords = normalize(query).split(' ').filter(word => word.length > 2);
  const labelWords = normalize(label).split(' ').filter(word => word.length > 2);
  let score = scoreText(normalize(query), [label]);
  for (const wanted of labelWords) {
    for (const actual of qWords) {
      const longest = Math.max(wanted.length, actual.length);
      if (longest < 4) continue;
      const similarity = 1 - editDistance(wanted, actual) / longest;
      if (similarity >= 0.72) score = Math.max(score, Math.round(similarity * 9));
    }
  }
  return score;
}

class ThothDataEngine {
  constructor(htmlPath) {
    const started = Date.now();
    const source = fs.readFileSync(htmlPath, 'utf8');
    this.data = extractJson(source, 'D', 'V');
    this.breakdowns = extractJson(source, 'XB', 'HK');
    this.hKeys = this.data.HK;
    this.iKeys = this.data.IK;
    this.governorates = this.data.R;
    this.cache = new Map();
    this.loadedInMs = Date.now() - started;
  }

  aggregateHouseholds(governorate = -1, area = -1) {
    const out = Object.fromEntries(this.hKeys.map(key => [key, 0]));
    for (const row of this.data.H) {
      if ((governorate < 0 || row[0] === governorate) && (area < 0 || row[1] === area)) {
        this.hKeys.forEach((key, index) => { out[key] += row[index]; });
      }
    }
    return out;
  }

  aggregatePeople(governorate = -1, area = -1, gender = -1) {
    const out = Object.fromEntries(this.iKeys.map(key => [key, 0]));
    for (const row of this.data.I) {
      if ((governorate < 0 || row[0] === governorate) && (area < 0 || row[1] === area) && (gender < 0 || row[2] === gender)) {
        this.iKeys.forEach((key, index) => { out[key] += row[index]; });
      }
    }
    return out;
  }

  resolveScope(question, clientContext = {}) {
    const q = normalize(question);
    const selection = clientContext && clientContext.selection || {};
    let governorate = this.governorates.findIndex(name => normalize(name) === normalize(selection.governorate));
    let explicitGovernorate = false;
    for (let index = 0; index < this.governorates.length; index += 1) {
      const name = this.governorates[index];
      const aliases = [name, ...(ARABIC_GOVERNORATES[name] || [])].map(normalize);
      if (aliases.some(alias => alias && q.includes(alias))) { governorate = index; explicitGovernorate = true; break; }
    }
    let area = /\b(rural|countryside)\b|ريف|ريفي/.test(q) ? 1 : /\b(urban|city)\b|حضر|حضري/.test(q) ? 0 : -1;
    if (area < 0) area = /rural|ريف/i.test(selection.area || '') ? 1 : /urban|حضر/i.test(selection.area || '') ? 0 : -1;
    let gender = /\b(female|women|woman|girls?)\b|اناث|نساء|ستات|بنات/.test(q) ? 1 : /\b(male|men|man|boys?)\b|ذكور|رجال|ولاد/.test(q) ? 0 : -1;
    if (gender < 0) gender = /female|نساء|اناث/i.test(selection.gender || '') ? 1 : /male|رجال|ذكور/i.test(selection.gender || '') ? 0 : -1;
    return { governorate, area, gender, explicitGovernorate, q };
  }

  matchedMetrics(query) {
    const scored = METRICS.map(metric => ({ metric, score: scoreText(query, [metric.name, metric.id, ...metric.aliases]) }))
      .filter(item => item.score > 0).sort((a, b) => b.score - a.score);
    const threshold = scored[0] && scored[0].score >= 20 ? 10 : 3;
    return scored.filter(item => item.score >= threshold).slice(0, 6).map(item => item.metric);
  }

  matchedBreakdowns(query) {
    return this.breakdowns.map(item => ({ item, score: scoreText(query, [item.n, item.b, ...item.c]) }))
      .filter(entry => entry.score >= 10).sort((a, b) => b.score - a.score).slice(0, 2).map(entry => entry.item);
  }

  matchVisibleChart(query, clientContext = {}) {
    const charts = Array.isArray(clientContext.visibleCharts) ? clientContext.visibleCharts : [];
    const meaningful = normalize(query)
      .replace(/\b(explain|describe|show|tell|understand|this|that|the|chart|graph|plot|panel)\b/g, ' ')
      .replace(/اشرح|فسر|فهمني|وريني|التشارت|الشارت|الرسم|البياني|البانل|ده|دي|دا/g, ' ')
      .replace(/\s+/g, ' ').trim();
    if (!meaningful) return null;
    const positions = [
      ['chart 1', 'first chart', 'top left', 'اول تشارت', 'التشارت الاول', 'فوق الشمال'],
      ['chart 2', 'second chart', 'top right', 'تاني تشارت', 'التشارت التاني', 'فوق اليمين'],
      ['chart 3', 'third chart', 'bottom left', 'تالت تشارت', 'التشارت التالت', 'تحت الشمال'],
      ['chart 4', 'fourth chart', 'bottom right', 'رابع تشارت', 'التشارت الرابع', 'تحت اليمين']
    ];
    const ranked = charts.map((chart, index) => {
      const title = normalize(chart.title);
      const aliases = [];
      if (/where household money goes|money goes/.test(title)) aliases.push('household spending', 'spending chart', 'الفلوس بتروح فين', 'توزيع الانفاق', 'المصروفات');
      if (title === 'breakdown') aliases.push('breakdown chart', 'تفصيل', 'التقسيم', 'التوزيع');
      if (/beyond income/.test(title)) aliases.push('housing work schooling', 'beyond income', 'ما بعد الدخل', 'السكن والعمل والتعليم');
      if (/rural.*urban/.test(title)) aliases.push('rural urban comparison', 'rural versus urban', 'الريف والحضر', 'ريف وحضر');
      if (/governorate map/.test(title)) aliases.push('map', 'egypt map', 'خريطه', 'خريطة المحافظات');
      if (/spread.*governorates/.test(title)) aliases.push('governorate comparison', 'spread', 'مقارنه المحافظات', 'انتشار المحافظات');
      const labels = [chart.title, ...(chart.selections || []), ...aliases, ...(positions[index] || [])].filter(Boolean);
      const scores = labels.map(label => fuzzyLabelScore(query, label));
      return { chart, score: Math.max(0, ...scores) };
    }).sort((a, b) => b.score - a.score);
    if (!ranked.length || ranked[0].score < 7) return null;
    const best = ranked[0], second = ranked[1];
    return {
      id: best.chart.id,
      dashboard: clientContext.activeDashboard || 'Overview',
      title: best.chart.title,
      selections: best.chart.selections || [],
      subtitle: best.chart.subtitle || '',
      confidence: best.score >= 20 ? 'high' : 'medium',
      ambiguousWith: second && best.score < 20 && second.score >= best.score - 1 ? second.chart.title : null
    };
  }

  metricValue(metric, governorate, area, gender) {
    const aggregate = metric.kind === 'h' ? this.aggregateHouseholds(governorate, area) : this.aggregatePeople(governorate, area, gender);
    return round(metric.calc(aggregate), metric.unit.startsWith('EGP') ? 0 : 1);
  }

  breakdownValue(item, scope) {
    const sums = item.c.map(() => 0);
    for (const row of item.r) {
      if ((scope.governorate < 0 || row[0] === scope.governorate) && (scope.area < 0 || row[1] === scope.area) && (!item.i || scope.gender < 0 || row[2] === scope.gender)) {
        item.c.forEach((_, index) => { sums[index] += row[3 + index] || 0; });
      }
    }
    const total = sums.reduce((sum, value) => sum + value, 0);
    return {
      dimension: item.n,
      population: item.b,
      categories: item.c.map((name, index) => ({ name, share: total ? round(100 * sums[index] / total, 1) : null })).filter(row => row.share !== null)
    };
  }

  query(message, clientContext = {}, history = []) {
    const started = Date.now();
    const recentUserText = (Array.isArray(history) ? history : []).filter(turn => turn && turn.role !== 'model').slice(-2).map(turn => turn.text).join(' ');
    const searchText = `${message} ${recentUserText}`;
    const scope = this.resolveScope(searchText, clientContext);
    const chartMatch = this.matchVisibleChart(searchText, clientContext);
    const chartSignature = (clientContext.visibleCharts || []).map(chart => [chart.id, chart.title, chart.selections]).flat(3).join('|');
    const cacheKey = JSON.stringify([normalize(searchText), scope.governorate, scope.area, scope.gender, clientContext.activeDashboard, chartSignature]);
    if (this.cache.has(cacheKey)) return { ...this.cache.get(cacheKey), cacheHit: true, retrievalMs: Date.now() - started };

    const dataTerms = /dashboard|survey|data|chart|metric|indicator|governorate|rural|urban|income|spend|education|health|work|job|water|internet|insurance|household|breakdown|داتا|داشبورد|مؤشر|محافظ|ريف|حضر|دخل|انفاق|تعليم|صحه|عمل|وظيف|مياه|انترنت|تامين|اسره|بيانات/.test(scope.q);
    let metrics = this.matchedMetrics(scope.q);
    let breakdowns = this.matchedBreakdowns(scope.q);
    const asksCatalog = /available|contain|coverage|what data|what can|ايه الداتا|البيانات المتاحه|بتتكلم عن ايه/.test(scope.q);
    let ruralUrban = (/rural/.test(scope.q) && /urban/.test(scope.q)) || (scope.q.includes('ريف') && scope.q.includes('حضر')) || /compare.*area|مقارنه.*ريف/.test(scope.q);
    const chartReference = /chart|graph|plot|panel|تشارت|شارت|رسم|بانل/.test(scope.q);
    const chartText = chartMatch ? normalize([chartMatch.title, ...chartMatch.selections].join(' ')) : '';

    if (chartMatch) {
      const selectedMetrics = this.matchedMetrics(chartText);
      if (selectedMetrics.length) metrics = selectedMetrics;
      const selectedBreakdown = this.breakdowns.map(item => ({ item, score: scoreText(chartText, [item.n]) })).sort((a, b) => b.score - a.score)[0];
      if (selectedBreakdown && selectedBreakdown.score >= 20) { breakdowns = [selectedBreakdown.item]; metrics = []; }
      if (/assets owned|asset|اصول|ممتلكات/.test(chartText)) metrics = METRICS.filter(metric => metric.id.startsWith('asset_'));
      else if (/spending categor|where household money goes|spending|انفاق|مصروف/.test(chartText)) metrics = METRICS.filter(metric => ['food', 'housing', 'health_spending', 'education_spending', 'transport'].includes(metric.id));
      else if (/income source|where income|main source|مصدر الدخل/.test(chartText)) metrics = METRICS.filter(metric => ['wages', 'business', 'remittances'].includes(metric.id));
      else if (/education|تعليم/.test(chartText)) metrics = METRICS.filter(metric => ['literacy', 'enrolment', 'secondary_education', 'university'].includes(metric.id));
      else if (/insurance.*chronic|chronic.*insurance/.test(chartText)) metrics = METRICS.filter(metric => ['insurance', 'chronic'].includes(metric.id));
      else if (/gender profile|gender outcome/.test(chartText)) metrics = METRICS.filter(metric => ['labour', 'unemployment', 'literacy', 'insurance'].includes(metric.id));
      if (/rural.*urban|urban.*rural|ريف.*حضر|حضر.*ريف/.test(chartText)) ruralUrban = true;
    }
    if (ruralUrban) scope.area = -1;
    const ranking = /highest|lowest|top|bottom|best|worst|rank|most|least|اعلي|اقل|اكتر|اكثر|اقل|ترتيب|افضل|اسوا/.test(scope.q);

    const chartNeedsClarification = chartReference && !chartMatch && Array.isArray(clientContext.visibleCharts) && clientContext.visibleCharts.length > 1;
    if (!metrics.length && dataTerms && !chartNeedsClarification) metrics = METRICS.filter(metric => ['income', 'spending', 'food', 'literacy', 'insurance', 'unemployment'].includes(metric.id));
    if (!breakdowns.length && clientContext.selectedBreakdown) {
      const selected = this.breakdowns.find(item => normalize(item.n) === normalize(clientContext.selectedBreakdown));
      if (selected && /breakdown|فئات|تفصيل|توزيع/.test(scope.q)) breakdowns = [selected];
    }

    const used = dataTerms || chartReference || Boolean(chartMatch) || metrics.length > 0 || breakdowns.length > 0 || asksCatalog || scope.explicitGovernorate;
    if (!used) return { dataUsed: false, retrievalMs: Date.now() - started, cacheHit: false };

    const location = scope.governorate >= 0 ? this.governorates[scope.governorate] : 'Egypt';
    const areaName = scope.area === 1 ? 'Rural' : scope.area === 0 ? 'Urban' : 'All areas';
    const genderName = scope.gender === 1 ? 'Female' : scope.gender === 0 ? 'Male' : 'All genders';
    const facts = metrics.map(metric => ({ metric: metric.name, value: this.metricValue(metric, scope.governorate, scope.area, scope.gender), unit: metric.unit }));
    const comparisons = ruralUrban ? metrics.map(metric => ({
      metric: metric.name,
      urban: this.metricValue(metric, scope.governorate, 0, scope.gender),
      rural: this.metricValue(metric, scope.governorate, 1, scope.gender),
      unit: metric.unit
    })) : [];
    const rankings = ranking ? metrics.slice(0, 3).map(metric => {
      const rows = this.governorates.map((name, index) => ({ name, value: this.metricValue(metric, index, scope.area, scope.gender) })).filter(row => row.value !== null).sort((a, b) => b.value - a.value);
      return { metric: metric.name, unit: metric.unit, highest: rows.slice(0, 5), lowest: rows.slice(-5).reverse() };
    }) : [];
    const result = {
      dataUsed: true,
      source: 'Egypt Household Survey 2021; survey-weighted estimates',
      activeDashboard: clientContext.activeDashboard || 'Overview',
      chartMatch,
      chartClarification: chartNeedsClarification ? clientContext.visibleCharts.map(chart => chart.title) : undefined,
      scope: { location, area: areaName, gender: genderName },
      facts,
      ruralUrbanComparisons: comparisons,
      governorateRankings: rankings,
      breakdowns: breakdowns.map(item => this.breakdownValue(item, scope)),
      catalog: asksCatalog ? { metrics: METRICS.map(metric => metric.name), breakdowns: this.breakdowns.map(item => item.n), governorates: this.governorates } : undefined,
      note: 'Values are computed locally from the complete embedded dashboard dataset. Percentages are percentage points unless stated otherwise.',
      cacheHit: false,
      retrievalMs: Date.now() - started
    };
    if (this.cache.size > 300) this.cache.delete(this.cache.keys().next().value);
    this.cache.set(cacheKey, result);
    return result;
  }

  stats() {
    return { governorates: this.governorates.length, householdRows: this.data.H.length, peopleRows: this.data.I.length, breakdowns: this.breakdowns.length, metrics: METRICS.length, loadedInMs: this.loadedInMs, cacheEntries: this.cache.size };
  }
}

module.exports = { ThothDataEngine, METRICS };
