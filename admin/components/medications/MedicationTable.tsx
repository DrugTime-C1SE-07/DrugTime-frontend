import {
  CheckCircle2,
  ChevronsLeft,
  ChevronsRight,
  Clock3,
  Globe2,
  Microscope,
  RotateCcw,
  X,
} from "lucide-react";

type Medication = {
  name: string;
  form: string;
  warning?: string;
  ingredient: string;
  strength: string;
  group: string;
  atc?: string;
  source: string;
  sourceTone: "dav" | "drugbank" | "manual" | "web";
  quality: "verified" | "pending" | "missing";
};

const medications: Medication[] = [
  {
    name: "Glucophage 850mg",
    form: "Viên nén bao phim",
    ingredient: "Metformin hydrochloride",
    strength: "850 mg / viên",
    group: "Đái tháo đường",
    atc: "A10BA02",
    source: "Scraped: DAV",
    sourceTone: "dav",
    quality: "verified",
  },
  {
    name: "Augmentin 1g",
    form: "Viên nén bao phim",
    ingredient: "Amoxicillin + Clavulanic acid",
    strength: "875mg + 125mg",
    group: "Kháng sinh",
    atc: "J01CR02",
    source: "Scraped: Drugbank",
    sourceTone: "drugbank",
    quality: "verified",
  },
  {
    name: "Hapacol 250",
    form: "Thuốc cốm sủi bọt",
    ingredient: "Paracetamol",
    strength: "250 mg / gói",
    group: "Giảm đau hạ sốt",
    atc: "N02BE01",
    source: "Scraped: DAV",
    sourceTone: "dav",
    quality: "verified",
  },
  {
    name: "Lexomil 6mg",
    form: "Viên nén chia bốn",
    warning: "△",
    ingredient: "Bromazepam",
    strength: "6 mg",
    group: "Hướng thần",
    atc: "N05BA08",
    source: "Scraped: DAV",
    sourceTone: "dav",
    quality: "pending",
  },
  {
    name: "Klamentin 500/125",
    form: "Viên nén bao phim",
    ingredient: "Amoxicillin + Acid clavulanic",
    strength: "500mg + 125mg",
    group: "Kháng sinh",
    atc: "J01CR02",
    source: "Scraped: Drugbank",
    sourceTone: "drugbank",
    quality: "pending",
  },
  {
    name: "Pyme AZI 500",
    form: "Viên nang cứng",
    ingredient: "Azithromycin",
    strength: "500 mg",
    group: "Kháng sinh",
    atc: "J01FA10",
    source: "Manual Entry",
    sourceTone: "manual",
    quality: "verified",
  },
  {
    name: "Cefixim 200-CGP",
    form: "",
    warning: "Dạng bào chế chưa rõ",
    ingredient: "Cefixime",
    strength: "200 mg",
    group: "Kháng sinh",
    atc: "J01DD08",
    source: "Scraped: Web",
    sourceTone: "web",
    quality: "missing",
  },
];

const qualityLabels = {
  verified: "Đã xác thực",
  pending: "Chờ duyệt",
  missing: "Thiếu thông tin",
};

function SourceIcon({ tone }: { tone: Medication["sourceTone"] }) {
  if (tone === "manual") {
    return <Microscope size={17} strokeWidth={2.2} aria-hidden="true" />;
  }

  if (tone === "web") {
    return <Globe2 size={17} strokeWidth={2.2} aria-hidden="true" />;
  }

  return <RotateCcw size={17} strokeWidth={2.2} aria-hidden="true" />;
}

function QualityIcon({ quality }: { quality: Medication["quality"] }) {
  if (quality === "missing") {
    return <X size={17} strokeWidth={2.5} aria-hidden="true" />;
  }

  if (quality === "pending") {
    return <Clock3 size={17} strokeWidth={2.4} aria-hidden="true" />;
  }

  return <CheckCircle2 size={17} strokeWidth={2.4} aria-hidden="true" />;
}

export default function MedicationTable() {
  return (
    <section className="medication-table-card">
      <div className="medication-table" role="table" aria-label="Danh mục thuốc tự lưu trữ">
        <div className="medication-table__head" role="row">
          <span>
            <input type="checkbox" aria-label="Chọn tất cả thuốc" />
          </span>
          <span className="medication-table__head-primary">Tên thuốc & dạng bào chế</span>
          <span>hoạt chất & hàm lượng</span>
          <span>nhóm bệnh lý / ATC</span>
          <span>nguồn dữ liệu</span>
          <span>chất lượng / xác thực</span>
        </div>

        {medications.map((medication) => (
          <div className={`medication-table__row medication-table__row--${medication.quality}`} role="row" key={medication.name}>
            <span>
              <input type="checkbox" aria-label={`Chọn ${medication.name}`} />
            </span>
            <span className="medication-name">
              <strong>
                {medication.name}
                {medication.warning === "△" ? <em aria-label="Cần lưu ý">△</em> : null}
              </strong>
              {medication.form ? <small>{medication.form}</small> : null}
              {medication.warning && medication.warning !== "△" ? <small className="text-red">⊙ {medication.warning}</small> : null}
            </span>
            <span className="medication-ingredient">
              <strong>{medication.ingredient}</strong>
              <small>{medication.strength}</small>
            </span>
            <span className="medication-group">
              <strong>{medication.group}</strong>
              {medication.atc ? <code>{medication.atc}</code> : null}
            </span>
            <span>
              <mark className={`medication-source medication-source--${medication.sourceTone}`}>
                <SourceIcon tone={medication.sourceTone} />
                {medication.source}
              </mark>
            </span>
            <span>
              <mark className={`medication-quality medication-quality--${medication.quality}`}>
                <QualityIcon quality={medication.quality} />
                {qualityLabels[medication.quality]}
              </mark>
            </span>
          </div>
        ))}
      </div>

      <div className="medication-pagination">
        <span>
          Hiển thị <strong>1 - 7</strong> trong tổng số <strong>14,850</strong> bản ghi
        </span>
        <label>
          Số hàng:
          <select defaultValue="10">
            <option value="10">10 / trang</option>
            <option value="25">25 / trang</option>
            <option value="50">50 / trang</option>
          </select>
        </label>
        <div className="medication-pages" aria-label="Phân trang">
          <button type="button" disabled aria-label="Trang đầu">
            <ChevronsLeft size={18} strokeWidth={2.3} />
          </button>
          <button type="button" disabled aria-label="Trang trước">
            ‹
          </button>
          <button type="button" className="is-active">
            1
          </button>
          <button type="button">2</button>
          <button type="button">3</button>
          <span>...</span>
          <button type="button">1485</button>
          <button type="button" aria-label="Trang sau">
            ›
          </button>
          <button type="button" aria-label="Trang cuối">
            <ChevronsRight size={18} strokeWidth={2.3} />
          </button>
        </div>
      </div>
    </section>
  );
}
