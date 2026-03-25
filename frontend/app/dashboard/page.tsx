// src/app/dashboard/page.tsx
import { Card, CardContent, CardDescription, CardHeader } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Info } from 'lucide-react';

export default function Dashboard() {
  return (
    <div className="container mx-auto px-8 py-12">
      <div className="mb-8">
        <h1 className="text-4xl font-bold text-gray-900 mb-2">Dashboard</h1>
        <p className="text-gray-600 text-lg">
          Your portfolio and investments will appear here.
        </p>
      </div>

      {/* Metrics using shadcn Card */}
      <div className="grid md:grid-cols-3 gap-6 mb-8">
        <Card>
          <CardHeader className="pb-3">
            <CardDescription>Total Invested</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-gray-900">$0</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardDescription>Total Earnings</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-green-600">$0</div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-3">
            <CardDescription>Active Projects</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="text-3xl font-bold text-gray-900">0</div>
          </CardContent>
        </Card>
      </div>

      {/* Empty State using shadcn Alert */}
      <Alert>
        <Info className="h-4 w-4" />
        <AlertDescription>
          No investments yet. Start exploring projects to build your portfolio!
        </AlertDescription>
      </Alert>

      {/* CTA */}
      <div className="mt-6 flex justify-center">
        <Button asChild>
          <a href="/explore">Explore Projects</a>
        </Button>
      </div>
    </div>
  );
}