import MedicationFilters from "../../../components/medications/MedicationFilters";
import MedicationHeader from "../../../components/medications/MedicationHeader";
import MedicationStatsGrid from "../../../components/medications/MedicationStatsGrid";
import MedicationSyncBanner from "../../../components/medications/MedicationSyncBanner";
import MedicationTable from "../../../components/medications/MedicationTable";

export default function MedicationsPage() {
  return (
    <section className="medications-page">
      <MedicationHeader />
      <MedicationStatsGrid />
      <MedicationFilters />
      <MedicationTable />
      <MedicationSyncBanner />
    </section>
  );
}
