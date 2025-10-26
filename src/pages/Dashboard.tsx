import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Scale, FileText, Users, Gavel, LogOut } from 'lucide-react';

const Dashboard = () => {
  const { user, userRole, loading, signOut } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!loading && !user) {
      navigate('/auth');
    }
  }, [user, loading, navigate]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p>Carregando...</p>
      </div>
    );
  }

  const handleLogout = async () => {
    await signOut();
    navigate('/auth');
  };

  const getRoleName = () => {
    switch (userRole?.role) {
      case 'juiz':
        return `Juiz ${userRole.judge_type ? `- ${userRole.judge_type.replace('_', ' ').toUpperCase()}` : ''}`;
      case 'criador_processo':
        return 'Criador de Processo';
      case 'representante':
        return 'Representante';
      default:
        return 'Usuário';
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-blue-100">
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 flex justify-between items-center">
          <div className="flex items-center space-x-3">
            <div className="bg-primary p-2 rounded-lg">
              <Scale className="h-6 w-6 text-primary-foreground" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-foreground">Sistema Judicial com IA</h1>
              <p className="text-sm text-muted-foreground">{getRoleName()}</p>
            </div>
          </div>
          <Button variant="outline" onClick={handleLogout}>
            <LogOut className="h-4 w-4 mr-2" />
            Sair
          </Button>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {userRole?.role === 'criador_processo' && (
            <>
              <Card className="hover:shadow-lg transition-shadow cursor-pointer" onClick={() => navigate('/criar-processo')}>
                <CardHeader>
                  <FileText className="h-8 w-8 text-primary mb-2" />
                  <CardTitle>Novo Processo</CardTitle>
                  <CardDescription>Criar um novo processo judicial</CardDescription>
                </CardHeader>
              </Card>
              <Card className="hover:shadow-lg transition-shadow cursor-pointer" onClick={() => navigate('/meus-processos')}>
                <CardHeader>
                  <FileText className="h-8 w-8 text-primary mb-2" />
                  <CardTitle>Meus Processos</CardTitle>
                  <CardDescription>Ver processos criados</CardDescription>
                </CardHeader>
              </Card>
            </>
          )}

          {userRole?.role === 'juiz' && (
            <>
              <Card className="hover:shadow-lg transition-shadow cursor-pointer" onClick={() => navigate('/pastas')}>
                <CardHeader>
                  <Gavel className="h-8 w-8 text-primary mb-2" />
                  <CardTitle>Pastas de Processos</CardTitle>
                  <CardDescription>Visualizar e julgar processos</CardDescription>
                </CardHeader>
              </Card>
              <Card className="hover:shadow-lg transition-shadow cursor-pointer" onClick={() => navigate('/solicitacoes')}>
                <CardHeader>
                  <FileText className="h-8 w-8 text-primary mb-2" />
                  <CardTitle>Solicitações de Informações</CardTitle>
                  <CardDescription>Gerenciar solicitações</CardDescription>
                </CardHeader>
              </Card>
            </>
          )}

          {userRole?.role === 'representante' && (
            <>
              <Card className="hover:shadow-lg transition-shadow cursor-pointer" onClick={() => navigate('/processos-representados')}>
                <CardHeader>
                  <Users className="h-8 w-8 text-primary mb-2" />
                  <CardTitle>Processos Representados</CardTitle>
                  <CardDescription>Ver processos que represento</CardDescription>
                </CardHeader>
              </Card>
            </>
          )}
        </div>
      </main>
    </div>
  );
};

export default Dashboard;
