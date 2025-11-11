import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { Plus, LogOut, AlertCircle, Clock, CheckCircle2 } from "lucide-react";
import { Badge } from "@/components/ui/badge";

interface Complaint {
  id: string;
  title: string;
  category: string;
  severity: string;
  status: string;
  created_at: string;
  is_anonymous: boolean;
  withdrawn_at?: string | null;
}

const Dashboard = () => {
  const navigate = useNavigate();
  const { toast } = useToast();
  const [user, setUser] = useState<any>(null);
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkAuth = async () => {
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        navigate("/auth");
        return;
      }
      setUser(session.user);
      await fetchComplaints(session.user.id);
    };

    checkAuth();

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (!session) {
        navigate("/auth");
      } else {
        setUser(session.user);
      }
    });

    return () => subscription.unsubscribe();
  }, [navigate]);

  const fetchComplaints = async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from("complaints")
        .select("*")
        .eq("student_id", userId)
        .order("created_at", { ascending: false });

      if (error) throw error;
      setComplaints(data || []);
    } catch (error: any) {
      toast({
        title: "Error",
        description: error.message,
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    navigate("/");
  };

  const activeComplaints = complaints.filter(c => c.status !== "resolved" && !c.withdrawn_at);
  const resolvedComplaints = complaints.filter(c => c.status === "resolved");

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case "high": return "bg-destructive text-destructive-foreground";
      case "medium": return "bg-orange-500 text-white";
      case "low": return "bg-accent text-accent-foreground";
      default: return "bg-muted text-muted-foreground";
    }
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case "submitted": return <Clock className="w-4 h-4" />;
      case "in_progress": return <AlertCircle className="w-4 h-4" />;
      case "resolved": return <CheckCircle2 className="w-4 h-4" />;
      default: return null;
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-background via-secondary to-background flex items-center justify-center">
        <div className="text-lg">Loading...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-secondary to-background">
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <div className="flex justify-between items-center mb-8">
          <div>
            <h1 className="text-4xl font-bold mb-2">Dashboard</h1>
            <p className="text-muted-foreground">Welcome back, {user?.user_metadata?.name || "Student"}!</p>
          </div>
          <Button
            variant="outline"
            onClick={handleSignOut}
            className="rounded-xl"
          >
            <LogOut className="w-4 h-4 mr-2" />
            Sign Out
          </Button>
        </div>

        {/* Stats */}
        <div className="grid md:grid-cols-3 gap-6 mb-8">
          <Card className="rounded-3xl shadow-lg">
            <CardHeader>
              <CardTitle className="text-lg">Active Complaints</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-4xl font-bold text-primary">{activeComplaints.length}</p>
              <p className="text-sm text-muted-foreground mt-2">Maximum 3 allowed</p>
            </CardContent>
          </Card>

          <Card className="rounded-3xl shadow-lg">
            <CardHeader>
              <CardTitle className="text-lg">Resolved</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-4xl font-bold text-accent">{resolvedComplaints.length}</p>
              <p className="text-sm text-muted-foreground mt-2">Total resolved</p>
            </CardContent>
          </Card>

          <Card className="rounded-3xl shadow-lg">
            <CardHeader>
              <CardTitle className="text-lg">Total Submitted</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-4xl font-bold">{complaints.length}</p>
              <p className="text-sm text-muted-foreground mt-2">All time</p>
            </CardContent>
          </Card>
        </div>

        {/* New Complaint Button */}
        <div className="mb-8">
          <Button
            size="lg"
            onClick={() => navigate("/submit-complaint")}
            disabled={activeComplaints.length >= 3}
            className="rounded-2xl bg-primary hover:bg-primary-hover shadow-lg"
          >
            <Plus className="w-5 h-5 mr-2" />
            Submit New Complaint
          </Button>
          {activeComplaints.length >= 3 && (
            <p className="text-sm text-muted-foreground mt-2">
              You have reached the maximum of 3 active complaints. Please wait for resolution.
            </p>
          )}
        </div>

        {/* Active Complaints */}
        <div className="mb-8">
          <h2 className="text-2xl font-bold mb-4">Active Complaints</h2>
          {activeComplaints.length === 0 ? (
            <Card className="rounded-3xl shadow-lg">
              <CardContent className="py-12 text-center">
                <p className="text-muted-foreground">No active complaints</p>
              </CardContent>
            </Card>
          ) : (
            <div className="grid gap-4">
              {activeComplaints.map((complaint) => (
                <Card key={complaint.id} className="rounded-3xl shadow-lg hover:shadow-xl transition-all cursor-pointer" onClick={() => navigate(`/complaint/${complaint.id}`)}>
                  <CardHeader>
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <CardTitle className="text-xl mb-2">{complaint.title}</CardTitle>
                        <CardDescription className="flex items-center gap-2">
                          {getStatusIcon(complaint.status)}
                          <span className="capitalize">{complaint.status.replace("_", " ")}</span>
                        </CardDescription>
                      </div>
                      <Badge className={getSeverityColor(complaint.severity)}>
                        {complaint.severity}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="flex gap-2">
                      <Badge variant="outline">{complaint.category}</Badge>
                      {complaint.is_anonymous && (
                        <Badge variant="secondary">Anonymous</Badge>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </div>

        {/* Resolved Complaints */}
        {resolvedComplaints.length > 0 && (
          <div>
            <h2 className="text-2xl font-bold mb-4">Resolved Complaints</h2>
            <div className="grid gap-4">
              {resolvedComplaints.map((complaint) => (
                <Card key={complaint.id} className="rounded-3xl shadow-lg opacity-75 hover:opacity-100 transition-all cursor-pointer" onClick={() => navigate(`/complaint/${complaint.id}`)}>
                  <CardHeader>
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <CardTitle className="text-xl mb-2">{complaint.title}</CardTitle>
                        <CardDescription className="flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-accent" />
                          <span>Resolved</span>
                        </CardDescription>
                      </div>
                      <Badge className={getSeverityColor(complaint.severity)}>
                        {complaint.severity}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <Badge variant="outline">{complaint.category}</Badge>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default Dashboard;
