// src/app/explore/page.tsx
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Badge } from '@/components/ui/badge';
import { Search } from 'lucide-react';

export default function Explore() {
  return (
    <div className="container mx-auto px-8 py-12">
      <div className="mb-8">
        <h1 className="text-4xl font-bold text-gray-900 mb-2">Explore Projects</h1>
        <p className="text-gray-600 text-lg">
          Discover solar energy projects available for investment.
        </p>
      </div>

      {/* Filters using shadcn components */}
      <Card className="mb-8">
        <CardContent className="pt-6">
          <div className="flex gap-4">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 h-4 w-4" />
              <Input
                type="text"
                placeholder="Search projects..."
                className="pl-10"
              />
            </div>
            <select className="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option>All Status</option>
              <option>Funding</option>
              <option>Active</option>
              <option>Completed</option>
            </select>
            <select className="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option>All Locations</option>
              <option>California</option>
              <option>Texas</option>
              <option>Florida</option>
            </select>
          </div>
        </CardContent>
      </Card>

      {/* Empty state using shadcn Card */}
      <Card className="text-center py-12">
        <CardHeader>
          <div className="text-6xl mb-4">🌞</div>
          <CardTitle>No projects available yet</CardTitle>
        </CardHeader>
        <CardContent>
          <CardDescription className="mb-4">
            Check back soon for new solar investment opportunities
          </CardDescription>
          <Badge variant="secondary" className="mt-2">
            Coming Soon
          </Badge>
        </CardContent>
      </Card>
    </div>
  );
}