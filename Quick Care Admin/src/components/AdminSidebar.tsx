import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Separator } from "@/components/ui/separator";
import {
  LayoutDashboard,
  Users,
  Settings,
  Database,
  FileText,
  Menu,
  LogOut,
  Monitor,
  BarChart
} from "lucide-react";
import { cn } from "@/lib/utils";
import { auth } from "@/lib/firebase";
import { signOut } from "firebase/auth";

interface AdminSidebarProps {
  activeSection: string;
  onSectionChange: (section: string) => void;
}

const menuItems = [
  { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
  { id: "emergency", label: "Emergency Requests", icon: FileText },
  { id: "ambulance", label: "Ambulance Bookings", icon: Monitor },
  { id: "drivers", label: "Driver Management", icon: Users },
  { id: "users", label: "User Management", icon: Users },
  { id: "reports", label: "Reports & Analytics", icon: BarChart }
];

export function AdminSidebar({ activeSection, onSectionChange }: AdminSidebarProps) {
  const [collapsed, setCollapsed] = useState(false);
  const [isLoggingOut, setIsLoggingOut] = useState(false);
  const navigate = useNavigate();

  const handleLogout = async () => {
    try {
      setIsLoggingOut(true);
      await signOut(auth);
      navigate("/login");
    } catch (error) {
      console.error("Logout error:", error);
    } finally {
      setIsLoggingOut(false);
    }
  };

  return (
    <div className={cn(
      "flex flex-col h-screen bg-slate-900 text-white transition-all duration-300",
      collapsed ? "w-16" : "w-64"
    )}>
      <div className="flex items-center justify-between p-4 border-b border-slate-700">
        {!collapsed && (
          <h2 className="text-xl font-bold text-blue-400">Quick Admin</h2>
        )}
        <Button
          variant="ghost"
          size="sm"
          onClick={() => setCollapsed(!collapsed)}
          className="text-slate-400 hover:text-white"
        >
          <Menu className="h-4 w-4" />
        </Button>
      </div>

      <ScrollArea className="flex-1 p-2">
        <nav className="space-y-2">
          {menuItems.map((item) => {
            const Icon = item.icon;
            return (
              <Button
                key={item.id}
                variant={activeSection === item.id ? "secondary" : "ghost"}
                className={cn(
                  "w-full justify-start text-slate-300 hover:text-white hover:bg-slate-800",
                  activeSection === item.id && "bg-blue-600 text-white",
                  collapsed && "px-2"
                )}
                onClick={() => onSectionChange(item.id)}
              >
                <Icon className="h-4 w-4" />
                {!collapsed && <span className="ml-2">{item.label}</span>}
              </Button>
            );
          })}
        </nav>
      </ScrollArea>

      <Separator className="bg-slate-700" />
      
      <div className="p-4">
        <Button
          variant="ghost"
          className={cn(
            "w-full justify-start text-red-400 hover:text-red-300 hover:bg-slate-800",
            collapsed && "px-2",
            isLoggingOut && "opacity-70 cursor-not-allowed"
          )}
          onClick={handleLogout}
          disabled={isLoggingOut}
        >
          {isLoggingOut ? (
            <>
              <div className="h-4 w-4 border-2 border-red-400 border-t-transparent rounded-full animate-spin"></div>
              {!collapsed && <span className="ml-2">Logging out...</span>}
            </>
          ) : (
            <>
              <LogOut className="h-4 w-4" />
              {!collapsed && <span className="ml-2">Logout</span>}
            </>
          )}
        </Button>
      </div>
    </div>
  );
}
