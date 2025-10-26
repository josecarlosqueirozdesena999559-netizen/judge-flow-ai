import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { Scale, ArrowRight } from 'lucide-react';

const Index = () => {
  const { user } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (user) {
      navigate('/dashboard');
    }
  }, [user, navigate]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-600 via-blue-700 to-blue-900">
      <div className="container mx-auto px-4 py-16">
        <div className="max-w-4xl mx-auto text-center text-white">
          <div className="flex justify-center mb-8">
            <div className="bg-white/10 backdrop-blur-sm p-6 rounded-full">
              <Scale className="h-20 w-20" />
            </div>
          </div>
          
          <h1 className="text-5xl md:text-6xl font-bold mb-6">
            Sistema Judicial com IA
          </h1>
          
          <p className="text-xl md:text-2xl mb-12 text-blue-100">
            Gestão inteligente de processos judiciais com auxílio de inteligência artificial
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-12">
            <div className="bg-white/10 backdrop-blur-sm p-6 rounded-lg">
              <h3 className="text-xl font-semibold mb-2">Criadores de Processo</h3>
              <p className="text-blue-100">Crie e gerencie processos com facilidade</p>
            </div>
            <div className="bg-white/10 backdrop-blur-sm p-6 rounded-lg">
              <h3 className="text-xl font-semibold mb-2">Juízes</h3>
              <p className="text-blue-100">Julgue processos com auxílio da IA</p>
            </div>
            <div className="bg-white/10 backdrop-blur-sm p-6 rounded-lg">
              <h3 className="text-xl font-semibold mb-2">Representantes</h3>
              <p className="text-blue-100">Acompanhe e defenda processos</p>
            </div>
          </div>

          <Button 
            size="lg" 
            className="bg-white text-blue-900 hover:bg-blue-50 text-lg px-8 py-6"
            onClick={() => navigate('/auth')}
          >
            Acessar Sistema
            <ArrowRight className="ml-2 h-5 w-5" />
          </Button>
        </div>
      </div>
    </div>
  );
};

export default Index;
