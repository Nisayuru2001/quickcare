import { useState, useCallback } from "react";
import { Reports } from "@/components/Reports";
import { DateRangePicker } from "@/components/ui/date-range-picker";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  FileText,
  TrendingUp,
  Ambulance,
  AlertCircle,
  Calendar,
  Download,
} from "lucide-react";
import { addDays } from "date-fns";

const reportTypes = [
  {
    id: "overview",
    name: "Service Overview",
    icon: TrendingUp,
    description: "Overall emergency response metrics"
  },
  {
    id: "emergency",
    name: "Medical Emergency Reports",
    icon: AlertCircle,
    description: "Critical medical emergency statistics"
  },
  {
    id: "ambulance",
    name: "Ambulance Requests",
    icon: Ambulance,
    description: "Bystander ambulance request details"
  },
  {
    id: "scheduled",
    name: "Scheduled Reports",
    icon: Calendar,
    description: "Automated report generation"
  }
];

export default function ReportsPage() {
  const [selectedReport, setSelectedReport] = useState("overview");
  const [dateRange, setDateRange] = useState({
    from: addDays(new Date(), -30),
    to: new Date(),
  });

  const handleFromChange = useCallback((date: Date) => {
    setDateRange(prev => ({ ...prev, from: date }));
  }, []);

  const handleToChange = useCallback((date: Date) => {
    setDateRange(prev => ({ ...prev, to: date }));
  }, []);

  return (
    <div className="flex h-screen bg-gray-100">
      {/* Sidebar */}
      <div className="w-64 bg-white shadow-sm">
        <div className="p-4">
          <h2 className="text-xl font-bold mb-4">Reports</h2>
          <div className="space-y-1">
            {reportTypes.map((report) => (
              <button
                key={report.id}
                onClick={() => setSelectedReport(report.id)}
                className={`w-full flex items-center space-x-3 px-4 py-2 rounded-lg text-left ${
                  selectedReport === report.id
                    ? "bg-primary text-primary-foreground"
                    : "hover:bg-gray-100"
                }`}
              >
                <report.icon className="h-5 w-5" />
                <span>{report.name}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 overflow-auto">
        <div className="p-8">
          <div className="mb-6 flex justify-between items-center">
            <div>
              <h1 className="text-2xl font-bold">
                {reportTypes.find(r => r.id === selectedReport)?.name}
              </h1>
              <p className="text-gray-500">
                {reportTypes.find(r => r.id === selectedReport)?.description}
              </p>
            </div>
            
            <div className="flex items-center gap-4">
              <DateRangePicker
                from={dateRange.from}
                to={dateRange.to}
                onFromChange={handleFromChange}
                onToChange={handleToChange}
              />
              <Button variant="outline">
                <FileText className="h-4 w-4 mr-2" />
                Export as PDF
              </Button>
            </div>
          </div>

          {/* Reports Content */}
          <Reports selectedReport={selectedReport} dateRange={dateRange} />
        </div>
      </div>
    </div>
  );
} 