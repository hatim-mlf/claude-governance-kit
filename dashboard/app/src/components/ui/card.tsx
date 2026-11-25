import type { ReactNode } from 'react'
import { clsx } from 'clsx'

interface CardProps {
  children: ReactNode
  className?: string
  onClick?: () => void
}

export function Card({ children, className, onClick }: CardProps) {
  return (
    <div 
      className={clsx('rounded-lg border bg-card text-card-foreground shadow-sm', className)}
      onClick={onClick}
    >
      {children}
    </div>
  )
}

export function CardHeader({ children, className, onClick }: CardProps) {
  return (
    <div 
      className={clsx('flex flex-col space-y-1.5 p-6', className)}
      onClick={onClick}
    >
      {children}
    </div>
  )
}

export function CardTitle({ children, className }: CardProps) {
  return <h3 className={clsx('text-lg font-semibold leading-none tracking-tight', className)}>{children}</h3>
}

export function CardDescription({ children, className }: CardProps) {
  return <p className={clsx('text-sm text-muted-foreground', className)}>{children}</p>
}

export function CardContent({ children, className }: CardProps) {
  return <div className={clsx('p-6 pt-0', className)}>{children}</div>
}