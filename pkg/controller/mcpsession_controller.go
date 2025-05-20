package controller

import (
	"context"
	"fmt"
	"time"

	"github.com/yourusername/tvm/pkg/apis/vvm/v1alpha1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/client-go/tools/record"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

var mcpLog = logf.Log.WithName("controller_mcpsession")

// AddMCPSession creates a new MCPSession Controller and adds it to the Manager
func AddMCPSession(mgr manager.Manager) error {
	return addMCPSession(mgr, newMCPSessionReconciler(mgr))
}

// newMCPSessionReconciler returns a new reconcile.Reconciler
func newMCPSessionReconciler(mgr manager.Manager) reconcile.Reconciler {
	return &ReconcileMCPSession{
		client:   mgr.GetClient(),
		scheme:   mgr.GetScheme(),
		recorder: mgr.GetEventRecorderFor("mcpsession-controller"),
	}
}

// addMCPSession adds a new Controller to mgr with r as the reconcile.Reconciler
func addMCPSession(mgr manager.Manager, r reconcile.Reconciler) error {
	// Create a new controller
	c, err := controller.New("mcpsession-controller", mgr, controller.Options{Reconciler: r})
	if err != nil {
		return err
	}

	// Watch for changes to MCPSession
	// Use the new API for controller-runtime v0.20.4
	err = c.Watch(
		source.Kind(
			mgr.GetCache(),
			&v1alpha1.MCPSession{},
			&handler.TypedEnqueueRequestForObject[*v1alpha1.MCPSession]{},
		),
	)
	if err != nil {
		return err
	}

	return nil
}

// ReconcileMCPSession reconciles a MCPSession object
type ReconcileMCPSession struct {
	client   client.Client
	scheme   *runtime.Scheme
	recorder record.EventRecorder
}

// Reconcile reads that state of the cluster for a MCPSession object and makes changes based on the state read
func (r *ReconcileMCPSession) Reconcile(ctx context.Context, request reconcile.Request) (reconcile.Result, error) {
	reqLogger := mcpLog.WithValues("Request.Namespace", request.Namespace, "Request.Name", request.Name)
	reqLogger.Info("Reconciling MCPSession")

	// Fetch the MCPSession instance
	instance := &v1alpha1.MCPSession{}
	err := r.client.Get(ctx, request.NamespacedName, instance)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Return and don't requeue
			return reconcile.Result{}, nil
		}
		// Error reading the object - requeue the request.
		return reconcile.Result{}, err
	}

	// Check if the MCPSession is being deleted
	if !instance.ObjectMeta.DeletionTimestamp.IsZero() {
		return r.handleDelete(ctx, instance)
	}

	// Handle different states
	switch instance.Status.State {
	case "":
		// New MCPSession, initialize it
		return r.handleNew(ctx, instance)
	case v1alpha1.MCPSessionStateCreating:
		// MCPSession is being created, check its status
		return r.handleCreating(ctx, instance)
	case v1alpha1.MCPSessionStateRunning:
		// MCPSession is running, update its status
		return r.handleRunning(ctx, instance)
	case v1alpha1.MCPSessionStateError:
		// MCPSession is in error state, try to recover
		return r.handleError(ctx, instance)
	case v1alpha1.MCPSessionStateDeleted:
		// MCPSession is deleted, clean up
		return reconcile.Result{}, nil
	default:
		// Unknown state
		instance.Status.State = v1alpha1.MCPSessionStateError
		instance.Status.Error = fmt.Sprintf("Unknown state: %s", instance.Status.State)
		err = r.client.Status().Update(ctx, instance)
		return reconcile.Result{}, err
	}
}

// handleNew handles a new MCPSession
func (r *ReconcileMCPSession) handleNew(ctx context.Context, instance *v1alpha1.MCPSession) (reconcile.Result, error) {
	// Update status to Creating
	instance.Status.State = v1alpha1.MCPSessionStateCreating
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err := r.client.Status().Update(ctx, instance)
	if err != nil {
		return reconcile.Result{}, err
	}

	// Check if we need to create a new MicroVM or use an existing one
	if instance.Spec.VMID == "" {
		// Create a new MicroVM for this session
		vm, err := r.createMicroVMForSession(ctx, instance)
		if err != nil {
			instance.Status.State = v1alpha1.MCPSessionStateError
			instance.Status.Error = err.Error()
			r.client.Status().Update(ctx, instance)
			return reconcile.Result{}, err
		}
		instance.Spec.VMID = vm.Name
		err = r.client.Update(ctx, instance)
		if err != nil {
			return reconcile.Result{}, err
		}
	}

	// Requeue to check status
	return reconcile.Result{RequeueAfter: 5 * time.Second}, nil
}

// handleCreating handles a MCPSession that is being created
func (r *ReconcileMCPSession) handleCreating(ctx context.Context, instance *v1alpha1.MCPSession) (reconcile.Result, error) {
	// Check if the MicroVM is ready
	vm := &v1alpha1.MicroVM{}
	err := r.client.Get(ctx, types.NamespacedName{Name: instance.Spec.VMID, Namespace: instance.Namespace}, vm)
	if err != nil {
		if errors.IsNotFound(err) {
			// MicroVM not found, create a new one
			vm, err = r.createMicroVMForSession(ctx, instance)
			if err != nil {
				instance.Status.State = v1alpha1.MCPSessionStateError
				instance.Status.Error = err.Error()
				r.client.Status().Update(ctx, instance)
				return reconcile.Result{}, err
			}
			instance.Spec.VMID = vm.Name
			err = r.client.Update(ctx, instance)
			if err != nil {
				return reconcile.Result{}, err
			}
		} else {
			// Error getting MicroVM
			instance.Status.State = v1alpha1.MCPSessionStateError
			instance.Status.Error = err.Error()
			r.client.Status().Update(ctx, instance)
			return reconcile.Result{}, err
		}
	}

	// Check if the MicroVM is running
	if vm.Status.State != v1alpha1.MicroVMStateRunning {
		// MicroVM not ready yet, requeue
		return reconcile.Result{RequeueAfter: 5 * time.Second}, nil
	}

	// MicroVM is ready, update session status
	instance.Status.State = v1alpha1.MCPSessionStateRunning
	instance.Status.ConnectionInfo = &v1alpha1.ConnectionInfo{
		URL:   fmt.Sprintf("http://%s:8080", vm.Status.HostPod),
		Token: "session-token", // In a real implementation, generate a secure token
	}
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		return reconcile.Result{}, err
	}

	return reconcile.Result{}, nil
}

// handleRunning handles a running MCPSession
func (r *ReconcileMCPSession) handleRunning(ctx context.Context, instance *v1alpha1.MCPSession) (reconcile.Result, error) {
	// Check if the MicroVM still exists
	vm := &v1alpha1.MicroVM{}
	err := r.client.Get(ctx, types.NamespacedName{Name: instance.Spec.VMID, Namespace: instance.Namespace}, vm)
	if err != nil {
		if errors.IsNotFound(err) {
			// MicroVM not found, create a new one
			vm, err = r.createMicroVMForSession(ctx, instance)
			if err != nil {
				instance.Status.State = v1alpha1.MCPSessionStateError
				instance.Status.Error = err.Error()
				r.client.Status().Update(ctx, instance)
				return reconcile.Result{}, err
			}
			instance.Spec.VMID = vm.Name
			err = r.client.Update(ctx, instance)
			if err != nil {
				return reconcile.Result{}, err
			}
			// Update session status
			instance.Status.State = v1alpha1.MCPSessionStateCreating
			instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
			err = r.client.Status().Update(ctx, instance)
			if err != nil {
				return reconcile.Result{}, err
			}
			return reconcile.Result{RequeueAfter: 5 * time.Second}, nil
		} else {
			// Error getting MicroVM
			instance.Status.State = v1alpha1.MCPSessionStateError
			instance.Status.Error = err.Error()
			r.client.Status().Update(ctx, instance)
			return reconcile.Result{}, err
		}
	}

	// Check if the MicroVM is running
	if vm.Status.State != v1alpha1.MicroVMStateRunning {
		// MicroVM not running, update session status
		instance.Status.State = v1alpha1.MCPSessionStateError
		instance.Status.Error = fmt.Sprintf("MicroVM %s is not running", vm.Name)
		err = r.client.Status().Update(ctx, instance)
		if err != nil {
			return reconcile.Result{}, err
		}
		return reconcile.Result{RequeueAfter: 5 * time.Second}, nil
	}

	// Check for session timeout
	if instance.Status.LastActivity != nil {
		timeout := 30 * time.Minute // Session timeout
		if time.Since(instance.Status.LastActivity.Time) > timeout {
			// Session timed out, delete it
			err = r.client.Delete(ctx, instance)
			if err != nil {
				return reconcile.Result{}, err
			}
			return reconcile.Result{}, nil
		}
	}

	// Update last activity
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		return reconcile.Result{}, err
	}

	// Requeue periodically to check for timeout
	return reconcile.Result{RequeueAfter: 5 * time.Minute}, nil
}

// handleError handles a MCPSession in error state
func (r *ReconcileMCPSession) handleError(ctx context.Context, instance *v1alpha1.MCPSession) (reconcile.Result, error) {
	// For now, just log the error
	mcpLog.Error(fmt.Errorf(instance.Status.Error), "MCPSession in error state", "namespace", instance.Namespace, "name", instance.Name)

	// Try to recover by creating a new MicroVM
	vm, err := r.createMicroVMForSession(ctx, instance)
	if err != nil {
		// Failed to recover, requeue
		return reconcile.Result{RequeueAfter: 30 * time.Second}, nil
	}

	// Update session with new MicroVM
	instance.Spec.VMID = vm.Name
	instance.Status.State = v1alpha1.MCPSessionStateCreating
	instance.Status.Error = ""
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err = r.client.Update(ctx, instance)
	if err != nil {
		return reconcile.Result{}, err
	}

	// Requeue to check status
	return reconcile.Result{RequeueAfter: 5 * time.Second}, nil
}

// handleDelete handles a MCPSession that is being deleted
func (r *ReconcileMCPSession) handleDelete(ctx context.Context, instance *v1alpha1.MCPSession) (reconcile.Result, error) {
	// Update status to Deleted
	instance.Status.State = v1alpha1.MCPSessionStateDeleted
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err := r.client.Status().Update(ctx, instance)
	if err != nil && !errors.IsNotFound(err) {
		return reconcile.Result{}, err
	}

	return reconcile.Result{}, nil
}

// createMicroVMForSession creates a new MicroVM for a session
func (r *ReconcileMCPSession) createMicroVMForSession(ctx context.Context, session *v1alpha1.MCPSession) (*v1alpha1.MicroVM, error) {
	// Create a new MicroVM
	vm := &v1alpha1.MicroVM{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("vm-%s", session.Name),
			Namespace: session.Namespace,
			OwnerReferences: []metav1.OwnerReference{
				{
					APIVersion: "vvm.tvm.github.com/v1alpha1",
					Kind:       "MCPSession",
					Name:       session.Name,
					UID:        session.UID,
				},
			},
		},
		Spec: v1alpha1.MicroVMSpec{
			Image:             "ubuntu:20.04", // Default image
			CPU:               1,              // Default CPU
			Memory:            512,            // Default memory
			MCPMode:           true,
			PersistentStorage: false,
		},
	}

	// Create the MicroVM
	err := r.client.Create(ctx, vm)
	if err != nil {
		return nil, err
	}

	return vm, nil
}
