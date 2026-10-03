"""Exact local guard policy; host Swapouts is traffic, not actual swap usage."""
import math

class Policy:
    def __init__(self, limits, baseline=None):
        self.limits=limits;self.baseline=baseline;self.over=0;self.last_swap=baseline
        if limits.get('host_swapouts_guard',False) and (type(baseline) is not int or baseline<0):
            raise ValueError('host Swapouts observation unavailable')

    def observe(self, rss, elapsed, free, swap=None):
        for name,value in (('elapsed',elapsed),('free disk',free)):
            if type(value) not in (int,float) or not math.isfinite(value) or value<0:
                raise ValueError(name+' observation unavailable')
        if type(rss) not in (int,float) or not math.isfinite(rss) or rss<0:
            raise ValueError('RSS observation unavailable')
        if self.limits.get('host_swapouts_guard',False):
            if type(swap) is not int or swap<0 or swap<self.last_swap:
                raise ValueError('host Swapouts observation unavailable/reset')
            self.last_swap=swap
        self.over=self.over+1 if rss>self.limits['rss_kib'] else 0
        if self.over>=self.limits.get('rss_over_samples',1):return 'rss'
        if self.limits.get('host_swapouts_guard',False) and swap>self.baseline:return 'host_swapouts_increased'
        if free<self.limits['disk_floor_bytes']:return 'disk_floor'
        if elapsed>self.limits['timeout_seconds']:return 'timeout'
        return None
