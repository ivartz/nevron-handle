## Deploy
```bash
cd envs/<env>
<terraform init>
terraform plan/apply
```

## Environments (envs)

### Hypervisor Flavor Deployment Compatibility Matrix

#### compute-01,2,3,4

```
n1.micro  m1.tiny   n1.small  n1.medium n1.large  n1.work1  n1.work2  n1.max tf-env  verified
-         -         -         1         1         -         -         -      prod1   x
-         -         2         -         1         -         -         -      prod2   x
-         -         -         -         -         10        -         -      swarm1  x
-         -         -         -         -         -         1         -      swarm2  x
-         -         -         -         -         -         -         1      max     x
-         2         -         -         1         -         -         -      legacy1 x
4         -         -         -         1         -         -         -      legacy2 x
-         2         -         -         -         8         -         -      retro1  x
4         -         -         -         -         8         -         -      retro2  x
```
