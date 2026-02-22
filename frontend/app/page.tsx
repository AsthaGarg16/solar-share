import Navbar from '@/components/Navbar';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import Link from 'next/link';

export default function Home() {
  return (
    <main>
      <Navbar />
      
      <div className="container mx-auto px-4 py-16">
        {/* Hero Section */}
        <div className="text-center mb-16">
          <h1 className="text-5xl font-bold mb-4">
            Invest in Solar, Earn Passive Income
          </h1>
          <p className="text-xl text-gray-600 mb-8">
            Own a fraction of real solar installations. Get paid when they generate energy.
          </p>
          <Link href="/projects">
            <Button size="lg" className="text-lg px-8 py-6">
              Browse Projects
            </Button>
          </Link>
        </div>

        {/* Feature Cards */}
        <div className="grid md:grid-cols-3 gap-8">
          <Card>
            <CardHeader>
              <CardTitle>🌞 Real Solar Assets</CardTitle>
            </CardHeader>
            <CardContent>
              <CardDescription>
                Invest in verified solar installations on real homes. 
                Every project is backed by physical assets.
              </CardDescription>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>💰 Passive Income</CardTitle>
            </CardHeader>
            <CardContent>
              <CardDescription>
                Earn dividends automatically when solar panels generate energy. 
                Claim anytime, no lock-in period.
              </CardDescription>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>🗳️ Democratic Governance</CardTitle>
            </CardHeader>
            <CardContent>
              <CardDescription>
                Vote on repairs and maintenance. Your voting power equals 
                your ownership stake.
              </CardDescription>
            </CardContent>
          </Card>
        </div>
      </div>
    </main>
  );
}