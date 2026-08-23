import { type ReactNode } from 'react'
import { clsx } from 'clsx'

interface ScrollAreaProps {
  children: ReactNode
  className?: string
}

export function ScrollArea({ children, className }: ScrollAreaProps) {
  return (
    <div className={clsx('relative overflow-auto scrollbar-thin', className)}>
      {children}
    </div>
  )
}