"""Split a nonsingular 3x3 source matrix into two rotations and signed scale."""
import itertools, math

def transpose(a):
    return [list(row) for row in zip(*a)]

def multiply(a, b):
    return [[sum((a[i][k] * b[k][j] for k in range(3))) for j in range(3)] for i in range(3)]

def identity():
    return [[float(i == j) for j in range(3)] for i in range(3)]

def determinant(a):
    return a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])

def diagonal(values):
    return [[values[i] if i == j else 0.0 for j in range(3)] for i in range(3)]

def error(a, b):
    return max((abs(a[i][j] - b[i][j]) for i in range(3) for j in range(3)))

def quaternion(a):
    trace = sum((a[i][i] for i in range(3)))
    if trace > 0.0:
        s = math.sqrt(trace + 1.0) * 2.0
        q = [(a[2][1] - a[1][2]) / s, (a[0][2] - a[2][0]) / s, (a[1][0] - a[0][1]) / s, s * 0.25]
    else:
        i = max(range(3), key=lambda k: a[k][k])
        j = (i + 1) % 3
        k = (i + 2) % 3
        s = math.sqrt(max(0.0, 1.0 + a[i][i] - a[j][j] - a[k][k])) * 2.0
        assert s > 1e-12
        q = [0.0] * 4
        q[i] = s * 0.25
        q[j] = (a[i][j] + a[j][i]) / s
        q[k] = (a[i][k] + a[k][i]) / s
        q[3] = (a[k][j] - a[j][k]) / s
    length = math.sqrt(sum((x * x for x in q)))
    return [x / length for x in q]

def rotation(q):
    x, y, z, w = q
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)], [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)], [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]

def eigen_symmetric(a):
    current = [r[:] for r in a]
    vectors = identity()
    scale = max((abs(x) for row in a for x in row))
    assert scale > 0.0
    for _ in range(40):
        p, q = max([(0, 1), (0, 2), (1, 2)], key=lambda pair: abs(current[pair[0]][pair[1]]))
        if abs(current[p][q]) < scale * 1e-14:
            break
        tau = (current[q][q] - current[p][p]) / (2 * current[p][q])
        t = (1.0 if tau >= 0.0 else -1.0) / (abs(tau) + math.sqrt(1 + tau * tau))
        c = 1 / math.sqrt(1 + t * t)
        s = t * c
        change = identity()
        change[p][p] = change[q][q] = c
        change[p][q] = s
        change[q][p] = -s
        current = multiply(transpose(change), multiply(current, change))
        vectors = multiply(vectors, change)
    else:
        raise ValueError('Symmetric eigensolver did not settle')
    order = sorted(range(3), key=lambda i: current[i][i], reverse=True)
    return ([current[i][i] for i in order], [[vectors[r][i] for i in order] for r in range(3)])

def factor(a, previous=None):
    assert all((math.isfinite(x) for row in a for x in row))
    values, v = eigen_symmetric(multiply(transpose(a), a))
    s = [math.sqrt(max(0.0, x)) for x in values]
    assert min(s) > max(s) * 1e-08 and min(s) > 1e-12, 'Singular or ill-conditioned source matrix'
    u = multiply(a, v)
    for r in range(3):
        for col in range(3):
            u[r][col] /= s[col]
    if determinant(u) < 0.0:
        for r in range(3):
            u[r][2] *= -1
        s[2] *= -1
    if determinant(v) < 0.0:
        for r in range(3):
            v[r][2] *= -1
        s[2] *= -1
    best = None
    for order in itertools.permutations(range(3)) if previous else [(0, 1, 2)]:
        for signs in itertools.product([-1.0, 1.0], repeat=3):
            left = [[u[r][order[col]] * signs[col] for col in range(3)] for r in range(3)]
            right = [[v[r][order[col]] * signs[col] for col in range(3)] for r in range(3)]
            if determinant(left) < 0.999 or determinant(right) < 0.999:
                continue
            lq = quaternion(left)
            rq = quaternion(transpose(right))
            scales = [s[i] for i in order]
            score = sum((abs(sum((x * y for x, y in zip(q, p)))) for q, p in zip((lq, rq), previous))) if previous else 0.0
            if best is None or score > best[0]:
                best = (score, lq, scales, rq)
    assert best is not None
    _, lq, scales, rq = best
    if previous:
        if sum((x * y for x, y in zip(lq, previous[0]))) < 0.0:
            lq = [-x for x in lq]
        if sum((x * y for x, y in zip(rq, previous[1]))) < 0.0:
            rq = [-x for x in rq]
    rebuilt = multiply(rotation(lq), multiply(diagonal(scales), rotation(rq)))
    assert error(a, rebuilt) < max(1.0, max((abs(x) for row in a for x in row))) * 1e-07, (a, rebuilt)
    return (lq, scales, rq, error(a, rebuilt))
