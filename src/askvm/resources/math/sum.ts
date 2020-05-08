import { resource } from '../../lib/resource';
import { lambda, string, Typed, untyped } from '../../lib/typed';

export const sum = resource<Typed<(a: number, b: number) => number>>({
  type: lambda(string, string),
  resolver(a: number, b: number): number {
    return untyped(a) + untyped(b);
  },
});