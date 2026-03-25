'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, Compass } from 'lucide-react';

export default function Sidebar() {
  const [isExpanded, setIsExpanded] = useState(false);
  const pathname = usePathname();

  const menuItems = [
    { name: 'Dashboard', icon: LayoutDashboard, href: '/dashboard' },
    { name: 'Explore', icon: Compass, href: '/explore' },
  ];

  return (
    <aside
      className="fixed left-0 top-16 h-[calc(100vh-4rem)] bg-white border-r border-gray-200 transition-all duration-300 ease-in-out z-40"
      style={{ width: isExpanded ? '240px' : '72px' }}
      onMouseEnter={() => setIsExpanded(true)}
      onMouseLeave={() => setIsExpanded(false)}
    >
      <nav className="py-4">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = pathname === item.href;

          return (
            <Link
              key={item.name}
              href={item.href}
              className={`
                flex items-center px-6 py-3 transition-colors duration-200
                ${isActive 
                  ? 'bg-blue-50 text-blue-600 border-r-4 border-blue-600' 
                  : 'text-gray-700 hover:bg-gray-50'
                }
              `}
            >
              <Icon className={`w-6 h-6 flex-shrink-0 ${isActive ? 'text-blue-600' : 'text-gray-500'}`} />
              <span
                className={`ml-4 font-medium whitespace-nowrap transition-opacity duration-300 ${
                  isExpanded ? 'opacity-100' : 'opacity-0'
                }`}
                style={{ display: isExpanded ? 'block' : 'none' }}
              >
                {item.name}
              </span>
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}