import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import Link from 'next/link';

export default function Home() {
  return (
    <div className="container mx-auto px-8 py-12">
      {/* Hero Section */}
      <div className="max-w-4xl">
        <h1 className="text-5xl font-bold text-gray-900 mb-6">
          Welcome to SolarShare
        </h1>
        <p className="text-xl text-gray-600 mb-8 leading-relaxed">
          Invest in solar energy projects and earn passive income through fractional ownership. 
          Own a piece of the green energy revolution.
        </p>
        
        {/* CTA Buttons using shadcn Button */}
        <div className="flex gap-4">
          <Link href="/explore">
            <Button size="lg" className="px-8">
              Explore Projects
            </Button>
          </Link>
          <Link href="/dashboard">
            <Button size="lg" variant="outline" className="px-8">
              Go to Dashboard
            </Button>
          </Link>
        </div>
      </div>

      {/* Feature Cards using shadcn Card */}
      <div className="grid md:grid-cols-3 gap-6 mt-16">
        <Card className="hover:shadow-lg transition-shadow">
          <CardHeader>
            <div className="text-4xl mb-2">🌞</div>
            <CardTitle>Real Solar Assets</CardTitle>
          </CardHeader>
          <CardContent>
            <CardDescription>
              Invest in verified solar installations on real homes backed by physical assets.
            </CardDescription>
          </CardContent>
        </Card>

        <Card className="hover:shadow-lg transition-shadow">
          <CardHeader>
            <div className="text-4xl mb-2">💰</div>
            <CardTitle>Passive Income</CardTitle>
          </CardHeader>
          <CardContent>
            <CardDescription>
              Earn dividends automatically when solar panels generate energy.
            </CardDescription>
          </CardContent>
        </Card>

        <Card className="hover:shadow-lg transition-shadow">
          <CardHeader>
            <div className="text-4xl mb-2">🗳️</div>
            <CardTitle>Democratic Governance</CardTitle>
          </CardHeader>
          <CardContent>
            <CardDescription>
              Vote on repairs and maintenance based on your ownership stake.
            </CardDescription>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}