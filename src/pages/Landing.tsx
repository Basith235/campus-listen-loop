import { Button } from "@/components/ui/button";
import { useNavigate } from "react-router-dom";
import { Heart, Shield, MessageCircle } from "lucide-react";

const Landing = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-gradient-to-br from-background via-secondary to-background">
      {/* Hero Section */}
      <div className="container mx-auto px-4 py-20">
        <div className="text-center max-w-4xl mx-auto">
          <div className="inline-flex items-center gap-2 bg-primary/10 text-primary px-4 py-2 rounded-full mb-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
            <Heart className="w-4 h-4" />
            <span className="text-sm font-medium">We're here to help, you matter</span>
          </div>
          
          <h1 className="text-5xl md:text-7xl font-bold mb-6 bg-clip-text text-transparent bg-gradient-to-r from-primary via-accent to-primary animate-in fade-in slide-in-from-bottom-8 duration-700 delay-150">
            Your Voice Matters
          </h1>
          
          <p className="text-xl md:text-2xl text-muted-foreground mb-12 animate-in fade-in slide-in-from-bottom-8 duration-700 delay-300">
            A safe, transparent platform for Brototype students to share concerns and track resolutions.
          </p>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center animate-in fade-in slide-in-from-bottom-8 duration-700 delay-500">
            <Button 
              size="lg" 
              onClick={() => navigate("/auth")}
              className="text-lg px-8 py-6 rounded-2xl bg-primary hover:bg-primary-hover transition-all shadow-lg hover:shadow-xl"
            >
              Get Started
            </Button>
            <Button 
              size="lg" 
              variant="outline"
              onClick={() => navigate("/auth")}
              className="text-lg px-8 py-6 rounded-2xl border-2 hover:bg-secondary transition-all"
            >
              Sign In
            </Button>
          </div>
        </div>

        {/* Features */}
        <div className="grid md:grid-cols-3 gap-8 mt-24 max-w-5xl mx-auto">
          <div className="bg-card rounded-3xl p-8 shadow-lg hover:shadow-xl transition-all animate-in fade-in slide-in-from-bottom-8 duration-700 delay-700">
            <div className="w-14 h-14 bg-primary/10 rounded-2xl flex items-center justify-center mb-6">
              <Shield className="w-7 h-7 text-primary" />
            </div>
            <h3 className="text-xl font-semibold mb-3">Safe & Anonymous</h3>
            <p className="text-muted-foreground">
              Submit complaints anonymously with full identity protection. Your safety comes first.
            </p>
          </div>

          <div className="bg-card rounded-3xl p-8 shadow-lg hover:shadow-xl transition-all animate-in fade-in slide-in-from-bottom-8 duration-700 delay-[900ms]">
            <div className="w-14 h-14 bg-accent/10 rounded-2xl flex items-center justify-center mb-6">
              <MessageCircle className="w-7 h-7 text-accent" />
            </div>
            <h3 className="text-xl font-semibold mb-3">Track Everything</h3>
            <p className="text-muted-foreground">
              Follow every step of your complaint's journey with our transparent timeline system.
            </p>
          </div>

          <div className="bg-card rounded-3xl p-8 shadow-lg hover:shadow-xl transition-all animate-in fade-in slide-in-from-bottom-8 duration-700 delay-[1100ms]">
            <div className="w-14 h-14 bg-primary/10 rounded-2xl flex items-center justify-center mb-6">
              <Heart className="w-7 h-7 text-primary" />
            </div>
            <h3 className="text-xl font-semibold mb-3">Fair Resolution</h3>
            <p className="text-muted-foreground">
              Every complaint gets attention and proper resolution. We ensure fairness for all.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Landing;
