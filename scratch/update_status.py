with open("docs/STATUS.md", "r") as f:
    lines = f.readlines()

status = """- INBOX 61(26) (c): Gear part balance and tier differentiation (hull_parts.json / engine_parts.json rebalance).
  - Common cards rebalanced to always feature a single flat effect, boosted to a 5~12 minimum value range, enforcing their identity as solid foundational pieces.
  - Uncommon cards rebalanced to precisely dual flat effects (guaranteed combination).
  - Rare cards reworked to fully adopt the `multiply` mode (`×배수`), amplifying values by a ratio rather than flat addition.
  - Legendary cards rebalanced to feature exactly one flat additive effect and one multiplicative effect (`+배수 AND ×배수`).
  - Preserved specific rigid values for test fixtures like `engine_emergency_boost_pod` by migrating them to appropriate rarities (`uncommon`) to maintain test stability and logical coherence.
  - Test suites verifying gear categorization and edition compatibility remained fully intact and GREEN.
  - Moved item 26 to '처리 완료' in `INBOX.md` as its final step is complete.

"""
lines.insert(1, status)

with open("docs/STATUS.md", "w") as f:
    f.writelines(lines)
